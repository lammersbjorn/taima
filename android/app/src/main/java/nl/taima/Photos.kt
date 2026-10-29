package nl.taima

import android.content.Context
import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.google.gson.JsonObject
import kotlinx.coroutines.*
import java.util.UUID

object Photos {
    fun decode(bytes:ByteArray,sample:Int=1):android.graphics.Bitmap = android.graphics.ImageDecoder.decodeBitmap(
        android.graphics.ImageDecoder.createSource(java.nio.ByteBuffer.wrap(bytes))) {decoder,info,_ ->
        decoder.allocator=android.graphics.ImageDecoder.ALLOCATOR_SOFTWARE
        val ratio=maxOf(sample.toDouble(),maxOf(info.size.width,info.size.height)/2400.0,1.0)
        decoder.setTargetSize((info.size.width/ratio).toInt().coerceAtLeast(1),(info.size.height/ratio).toInt().coerceAtLeast(1))
    }

    fun stage(context:Context,uri:android.net.Uri):java.io.File {
        val folder=java.io.File(context.cacheDir,"captures").apply {mkdirs()}
        val file=java.io.File(folder,"draft-${UUID.randomUUID()}.jpg")
        try {
            val bytes=context.contentResolver.openInputStream(uri)!!.use {input ->
                val out=java.io.ByteArrayOutputStream();val buffer=ByteArray(8192)
                while(true) {val n=input.read(buffer);if(n<0) break;require(out.size()+n<=30*1024*1024);out.write(buffer,0,n)};out.toByteArray()
            }
            val bitmap=decode(bytes)
            try {file.outputStream().use {check(bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG,92,it))}}
            finally {bitmap.recycle()}
            return file
        } catch(e:Exception) {file.delete();throw e}
    }

    fun clearDraft(context: Context, draft: JsonObject) {
        listOf("androidDraftPhoto","androidBackPhoto","androidFlowerPhoto").forEach {key ->
            val uri=android.net.Uri.parse(draft.text(key))
            if(uri.scheme=="file") uri.path?.let {path ->
                val file=java.io.File(path);val folder=java.io.File(context.cacheDir,"captures")
                if(file.canonicalFile.parentFile==folder.canonicalFile && file.name.startsWith("draft-")) file.delete()
            }
        }
    }

    fun store(context: Context, db: BagDatabase, uri: android.net.Uri): String {
        val bytes=context.contentResolver.openInputStream(uri)!!.use { input ->
            val output=java.io.ByteArrayOutputStream();val buffer=ByteArray(8192)
            while(true) {val n=input.read(buffer);if(n<0) break;require(output.size()+n<=30*1024*1024);output.write(buffer,0,n)};output.toByteArray()
        }
        // The archive uses opaque photo data with iOS's .heic naming contract.
        // Both platform decoders inspect image bytes, preserving imported originals.
        val bounds=BitmapFactory.Options().apply {inJustDecodeBounds=true};BitmapFactory.decodeByteArray(bytes,0,bytes.size,bounds);require(bounds.outWidth>0 && bounds.outHeight>0)
        val bitmap=decode(bytes)
        val clean=try {java.io.ByteArrayOutputStream().also {check(bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG,92,it))}.toByteArray()} finally {bitmap.recycle()}
        val name="${UUID.randomUUID().toString().uppercase()}.heic";db.putPhoto(name,clean)
        return name
    }

    fun attach(context: Context, db: BagDatabase, draft: JsonObject): JsonObject {
        val bag=draft.deepCopy()
        mapOf("androidDraftPhoto" to "photoName","androidBackPhoto" to "backPhotoName","androidFlowerPhoto" to "extraPhotoNames").forEach { (key,target) ->
            val value=bag.text(key)
            if(value.isNotEmpty()) {
                val uri=android.net.Uri.parse(value)
                val name=store(context,db,uri)
                if(bag.text("coverPhotoName")==key) bag.addProperty("coverPhotoName",name)
                if(target=="extraPhotoNames") {val photos=bag.getAsJsonArray(target) ?: com.google.gson.JsonArray().also {bag.add(target,it)};photos.add(name)} else bag.addProperty(target,name)
                bag.remove(key)
            }
        }
        return bag
    }
}
@Composable internal fun PhotoGallery(bag: JsonObject) {
    val names=remember(bag) {Domain.view(bag).array("photoNames").map {it.asString}}
    names.forEach {StoredPhoto(it)}
}
@Composable internal fun StoredPhoto(name: String) {
    val context=LocalContext.current
    val bitmap by produceState<android.graphics.Bitmap?>(null,name) {
        value=withContext(Dispatchers.IO) {BagDatabase(context).use {db ->db.photo(name)?.let {bytes ->runCatching {Photos.decode(bytes,2)}.getOrNull()}}}
    }
    bitmap?.let {Image(it.asImageBitmap(),stringResource(R.string.bag_photo),Modifier.fillMaxWidth().heightIn(min=120.dp,max=400.dp),contentScale=ContentScale.Fit)}
}
@Composable internal fun PhotoChoices(bag: JsonObject, change: (JsonObject)->Unit) {
    val names=remember(bag) {buildList {
        listOf("photoName","backPhotoName").forEach {key ->bag.text(key).takeIf(String::isNotBlank)?.let {add(it)}}
        addAll(bag.array("extraPhotoNames").map {it.asString})
        listOf("androidDraftPhoto","androidBackPhoto","androidFlowerPhoto").filter {bag.text(it).isNotBlank()}.forEach {add(it)}
    }}
    names.forEachIndexed {index,name ->
        if(name.startsWith("android")) PendingPhoto(bag.text(name))
        FlowRow {
            RadioButton(selected=(bag.text("coverPhotoName").ifBlank {Domain.view(bag).text("mainPhoto")})==name,onClick={change(bag.deepCopy().apply {addProperty("coverPhotoName",name)})})
            TaimaTextButton(onClick={change(bag.deepCopy().apply {addProperty("coverPhotoName",name)})}) {Text(stringResource(R.string.cover_number,index+1))}
            TaimaTextButton(onClick={change(bag.deepCopy().apply {
                if(name.startsWith("android")) remove(name)
                listOf("photoName","backPhotoName","coverPhotoName").forEach {key ->if(text(key)==name) remove(key)}
                add("extraPhotoNames",com.google.gson.JsonArray().also {out ->array("extraPhotoNames").filter {it.asString!=name}.forEach {out.add(it)}})
            })}) {Text(stringResource(R.string.remove_photo))}
        }
    }
}

@Composable private fun PendingPhoto(uri:String) {
    val context=LocalContext.current
    val bitmap by produceState<android.graphics.Bitmap?>(null,uri) {
        value=withContext(Dispatchers.IO) {runCatching {android.graphics.ImageDecoder.decodeBitmap(android.graphics.ImageDecoder.createSource(context.contentResolver,android.net.Uri.parse(uri))) {decoder,_,_ ->decoder.setTargetSampleSize(4)}}.getOrNull()}
    }
    bitmap?.let {Image(it.asImageBitmap(),stringResource(R.string.bag_photo),Modifier.fillMaxWidth().heightIn(max=260.dp),contentScale=ContentScale.Fit)}
}

/** Decode at thumbnail size off the UI thread. Missing photos get a product glyph. */
@Composable internal fun BagThumbnail(bag:JsonObject) {
    val context=LocalContext.current
    val name=Domain.view(bag).text("mainPhoto")
    val bitmap by produceState<android.graphics.Bitmap?>(null,name) {
        value=withContext(Dispatchers.IO) {if(name.isBlank()) null else BagDatabase(context).use {db ->db.photo(name)?.let {runCatching {android.graphics.ImageDecoder.decodeBitmap(android.graphics.ImageDecoder.createSource(java.nio.ByteBuffer.wrap(it))) {decoder,info,_ ->
            decoder.allocator=android.graphics.ImageDecoder.ALLOCATOR_SOFTWARE
            val ratio=(maxOf(info.size.width,info.size.height)/256.0).coerceAtLeast(1.0)
            decoder.setTargetSize((info.size.width/ratio).toInt().coerceAtLeast(1),(info.size.height/ratio).toInt().coerceAtLeast(1))
        }}.getOrNull()}}}
    }
    Surface(Modifier.size(64.dp),shape=androidx.compose.foundation.shape.RoundedCornerShape(14.dp),color=MaterialTheme.colorScheme.surfaceContainerHigh) {
        bitmap?.let {Image(it.asImageBitmap(),null,Modifier.fillMaxSize(),contentScale=ContentScale.Crop)}
            ?: Box(contentAlignment=androidx.compose.ui.Alignment.Center) {Icon(androidx.compose.material.icons.Icons.Default.Inventory2,null,tint=MaterialTheme.colorScheme.onSurfaceVariant)}
    }
}
