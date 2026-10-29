package nl.taima

import android.content.Context
import android.graphics.ImageDecoder
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import com.google.gson.JsonArray
import com.google.gson.JsonObject
import com.googlecode.tesseract.android.TessBaseAPI
import kotlinx.coroutines.*
import java.io.File
import java.util.UUID

/** Bundled OCR. No Play services, network calls or runtime model downloads. */
object LabelOCR {
    fun read(context: Context, uri: Uri): String {
        val root=File(context.filesDir,"ocr");val models=File(root,"tessdata").apply { mkdirs() }
        listOf("eng","nld").forEach { lang ->
            val file=File(models,"$lang.traineddata")
            if(!file.exists()) context.assets.open("tessdata/$lang.traineddata").use { input -> file.outputStream().use { input.copyTo(it) } }
        }
        val source=ImageDecoder.createSource(context.contentResolver,uri)
        val bitmap=ImageDecoder.decodeBitmap(source) { decoder,info,_ ->
            decoder.allocator=ImageDecoder.ALLOCATOR_SOFTWARE
            val scale=(info.size.width.coerceAtLeast(info.size.height)/2400.0).coerceAtLeast(1.0)
            decoder.setTargetSize((info.size.width/scale).toInt(),(info.size.height/scale).toInt())
        }
        return readBitmap(context,bitmap)
    }
    fun readBytes(context: Context, bytes: ByteArray): String = readBitmap(context,android.graphics.BitmapFactory.decodeByteArray(bytes,0,bytes.size) ?: error("Invalid photo"))
    fun readBitmap(context: Context, bitmap: android.graphics.Bitmap): String {
        val root=File(context.filesDir,"ocr");val models=File(root,"tessdata").apply {mkdirs()}
        listOf("eng","nld").forEach {lang ->val file=File(models,"$lang.traineddata");if(!file.exists()) context.assets.open("tessdata/$lang.traineddata").use {input ->file.outputStream().use {input.copyTo(it)}}}
        val api=TessBaseAPI()
        try { check(api.init(root.path,"eng+nld"));api.setImage(bitmap);return api.utF8Text }
        finally {api.recycle();bitmap.recycle()}
    }
    fun lines(text: String) = JsonArray().apply {
        val rows=text.lines().filter(String::isNotBlank)
        rows.forEachIndexed { index,line -> add(obj("text" to line,"box" to obj("x" to 0.0,"y" to 1.0-(index+1.0)/rows.size,"width" to 1.0,"height" to 0.8/rows.size),"alternatives" to emptyList<String>())) }
    }
}
@Composable internal fun Scanner(onDraft: (JsonObject)->Unit) {
    val context=LocalContext.current;val scope=rememberCoroutineScope()
    var text by remember { mutableStateOf("") };var busy by remember { mutableStateOf(false) };var error by remember { mutableStateOf(false) };var matches by remember {mutableStateOf<JsonObject?>(null)};var selected by remember { mutableStateOf<Uri?>(null) }
    var live by remember {mutableStateOf(false)}
    var frames by remember {mutableStateOf<List<JsonObject>>(emptyList())}
    var fused by remember {mutableStateOf<JsonObject?>(null)}
    val livePhoto=remember {File(File(context.cacheDir,"captures").apply {mkdirs()},"live-${UUID.randomUUID()}.jpg")}
    DisposableEffect(livePhoto) {onDispose {livePhoto.delete()}}
    LaunchedEffect(frames) {if(frames.isNotEmpty()) {
        try {fused=withContext(Dispatchers.Default) {Domain.call("label.frames","frames" to frames).asJsonObject}}
        catch(e:CancellationException) {throw e} catch(_:Exception) {error=true}
    }}
    val capture=remember { File(File(context.cacheDir,"captures").apply { mkdirs() },"capture-${UUID.randomUUID()}.jpg") }
    val uri=remember { FileProvider.getUriForFile(context,"${context.packageName}.files",capture) }
    DisposableEffect(capture) {onDispose {capture.delete()}}
    fun read(photo: Uri) { if(busy) return;frames=emptyList();fused=null;selected=photo;busy=true;error=false
        scope.launch {try {text=withContext(Dispatchers.IO) {LabelOCR.read(context,photo)}} catch(e:CancellationException) {throw e} catch(_:Exception) {error=true} finally {busy=false} }
    }
    val camera=rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) {if(it) read(uri)}
    val picker=rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) {it?.let(::read)}
    Page {
        Text(stringResource(R.string.scan_review_help))
        OutlinedButton(onClick={live=!live},enabled=!busy) {Text(stringResource(if(live) R.string.pause_scan else R.string.rotate_scan))}
        if(live) {
            Text(stringResource(R.string.rotate_scan_help))
            LiveScanner(onFrame={reading,codes,bytes ->
                livePhoto.writeBytes(bytes);selected=Uri.fromFile(livePhoto);text=reading
                frames=(frames+obj("lines" to LabelOCR.lines(reading),"codes" to codes)).takeLast(24)
            },onError={error=true})
        }
        if(frames.isNotEmpty()) Text(stringResource(R.string.scan_frames,frames.size,fused?.array("fields")?.size ?: 0))
        Button(onClick={camera.launch(uri)},enabled=!busy && !live) {Text(stringResource(R.string.take_photo))}
        OutlinedButton(onClick={picker.launch(androidx.activity.result.PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))},enabled=!busy && !live) {Text(stringResource(R.string.choose_photo))}
        if(busy) LinearProgressIndicator(Modifier.fillMaxWidth())
        if(error) Text(stringResource(R.string.ocr_failed))
        OutlinedTextField(text,{text=it;frames=emptyList();fused=null},enabled=!live,label={Text(stringResource(R.string.recognized_text))},minLines=5,modifier=Modifier.fillMaxWidth())
        OutlinedButton(onClick={busy=true;scope.launch {try {
            matches=withContext(Dispatchers.IO) {
                val reading=(fused ?: Domain.call("label","lines" to LabelOCR.lines(text)).asJsonObject).getAsJsonObject("bag")
                BagDatabase(context).use {db ->Domain.call("lookup","bags" to db.all(),"texts" to text.lines(),"payloads" to listOf("productID","ean","sku").map {reading.text(it)}.filter(String::isNotBlank)).asJsonObject}
            }
        } catch(e:CancellationException) {throw e} catch(_:Exception) {error=true} finally {busy=false} }},enabled=!busy && !live && (text.isNotBlank() || frames.isNotEmpty())) {Text(stringResource(R.string.do_i_have))}
        matches?.let {result ->
            Text(stringResource(when(result.text("kind")) {"sameBag"->R.string.same_package;"sameProduct"->R.string.same_product;"sameStrain"->R.string.same_strain;else->R.string.new_product}))
            result.array("bags").forEach {entry ->val bag=entry.asJsonObject;Text(bag.text("name"));Text(bag.text("notes"));Text(number(Domain.view(bag).number("score")))}
        }
        Button(onClick={busy=true;scope.launch {try {
            val draft=withContext(Dispatchers.Default) {(if(frames.isNotEmpty()) Domain.call("label.frames","frames" to frames) else Domain.call("label","lines" to LabelOCR.lines(text))).asJsonObject.getAsJsonObject("bag")}
            // Store the reviewed photo with the draft only when the editor saves.
            selected?.let { photo ->
                val retained=File(File(context.cacheDir,"captures").apply {mkdirs()},"draft-${UUID.randomUUID()}.jpg")
                withContext(Dispatchers.IO) { context.contentResolver.openInputStream(photo)!!.use { input -> retained.outputStream().use {input.copyTo(it)} } }
                draft.addProperty("androidDraftPhoto",retained.toURI().toString())
            };onDraft(draft)
        } catch(e:CancellationException) {throw e} catch(_:Exception) {error=true} finally {busy=false} }},enabled=!busy && !live && (text.isNotBlank() || frames.isNotEmpty())) {Text(stringResource(R.string.review_label))}
    }
}
