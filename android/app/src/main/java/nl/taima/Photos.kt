package nl.taima

import android.content.Context
import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
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
    fun clearDraft(context: Context, draft: JsonObject) {
        listOf("androidDraftPhoto","androidBackPhoto","androidFlowerPhoto").forEach {key ->
            val uri=android.net.Uri.parse(draft.text(key))
            if(uri.scheme=="file") uri.path?.let {path ->
                val file=java.io.File(path);val folder=java.io.File(context.cacheDir,"captures")
                if(file.canonicalFile.parentFile==folder.canonicalFile && file.name.startsWith("draft-")) file.delete()
            }
        }
    }

    fun attach(context: Context, db: BagDatabase, draft: JsonObject): JsonObject {
        val bag=draft.deepCopy()
        mapOf("androidDraftPhoto" to "photoName","androidBackPhoto" to "backPhotoName","androidFlowerPhoto" to "extraPhotoNames").forEach { (key,target) ->
            val value=bag.text(key)
            if(value.isNotEmpty()) {
                val uri=android.net.Uri.parse(value)
                val bytes=context.contentResolver.openInputStream(uri)!!.use { input ->
                    val output=java.io.ByteArrayOutputStream();val buffer=ByteArray(8192)
                    while(true) {val n=input.read(buffer);if(n<0) break;require(output.size()+n<=30*1024*1024);output.write(buffer,0,n)};output.toByteArray()
                }
                // The archive uses opaque photo data with iOS's .heic naming contract.
                // Both platform decoders inspect image bytes, preserving imported originals.
                val bounds=BitmapFactory.Options().apply {inJustDecodeBounds=true};BitmapFactory.decodeByteArray(bytes,0,bytes.size,bounds);require(bounds.outWidth>0 && bounds.outHeight>0)
                val name="${UUID.randomUUID().toString().uppercase()}.heic";db.putPhoto(name,bytes)
                if(target=="extraPhotoNames") {val photos=bag.getAsJsonArray(target) ?: com.google.gson.JsonArray().also {bag.add(target,it)};photos.add(name)} else bag.addProperty(target,name)
                bag.remove(key)
            }
        }
        return bag
    }
}
@Composable internal fun PhotoGallery(bag: JsonObject) {
    val context=LocalContext.current
    val names=remember(bag) { Domain.view(bag).array("photoNames").map {it.asString} }
    names.forEach {name ->
        val bitmap by produceState<android.graphics.Bitmap?>(null,name) {
            value=withContext(Dispatchers.IO) {BagDatabase(context).use {db ->db.photo(name)?.let {bytes ->BitmapFactory.decodeByteArray(bytes,0,bytes.size,BitmapFactory.Options().apply {inSampleSize=2})}}}
        }
        bitmap?.let {Image(it.asImageBitmap(),stringResource(R.string.bag_photo),Modifier.fillMaxWidth().heightIn(min=120.dp,max=400.dp),contentScale=ContentScale.Fit)}
    }
}
