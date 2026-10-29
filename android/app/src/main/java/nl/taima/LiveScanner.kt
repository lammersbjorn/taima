package nl.taima

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Matrix
import android.os.SystemClock
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.google.gson.JsonObject
import com.google.zxing.*
import com.google.zxing.common.HybridBinarizer
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/** One bounded analyzer. Slow OCR drops frames without blocking the camera preview. */
@Composable internal fun LiveScanner(onFrame:(String,List<JsonObject>,ByteArray)->Unit,onError:()->Unit) {
    val context=LocalContext.current;val owner=LocalLifecycleOwner.current
    val frameCallback by rememberUpdatedState(onFrame);val errorCallback by rememberUpdatedState(onError)
    var allowed by remember {mutableStateOf(ContextCompat.checkSelfPermission(context,Manifest.permission.CAMERA)==PackageManager.PERMISSION_GRANTED)}
    val permission=rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {allowed=it}
    if(!allowed) {
        Text(stringResource(R.string.camera_permission_help))
        OutlinedButton(onClick={permission.launch(Manifest.permission.CAMERA)}) {Text(stringResource(R.string.allow_camera))}
        return
    }
    val preview=remember {PreviewView(context)}
    AndroidView(factory={preview},modifier=Modifier.fillMaxWidth().height(280.dp))
    DisposableEffect(owner,preview) {
        val active=AtomicBoolean(true);val executor=Executors.newSingleThreadExecutor();val main=ContextCompat.getMainExecutor(context)
        val future=ProcessCameraProvider.getInstance(context)
        var provider:ProcessCameraProvider?=null
        val view=Preview.Builder().build().also {it.setSurfaceProvider(preview.surfaceProvider)}
        val analysis=ImageAnalysis.Builder().setTargetResolution(android.util.Size(1280,960))
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST).build()
        val reader=MultiFormatReader().apply {setHints(mapOf(DecodeHintType.TRY_HARDER to true))}
        var last=0L
        analysis.setAnalyzer(executor) {image ->
            try {
                if(active.get() && SystemClock.elapsedRealtime()-last>=1200) {
                    last=SystemClock.elapsedRealtime()
                    val raw=image.toBitmap()
                    val upright=Bitmap.createBitmap(raw,0,0,raw.width,raw.height,Matrix().apply {postRotate(image.imageInfo.rotationDegrees.toFloat())},true)
                    if(upright!==raw) raw.recycle()
                    try {
                        val pixels=IntArray(upright.width*upright.height);upright.getPixels(pixels,0,upright.width,0,0,upright.width,upright.height)
                        val code=try {reader.decodeWithState(BinaryBitmap(HybridBinarizer(RGBLuminanceSource(upright.width,upright.height,pixels))))} catch(_:ReaderException) {null} finally {reader.reset()}
                        val codes=code?.let {listOf(obj("kind" to when(it.barcodeFormat) {BarcodeFormat.QR_CODE->"qr";BarcodeFormat.EAN_13,BarcodeFormat.EAN_8->"ean";BarcodeFormat.CODE_128->"code128";else->"other"},"payload" to it.text))}.orEmpty()
                        val bytes=java.io.ByteArrayOutputStream().use {output ->upright.compress(Bitmap.CompressFormat.JPEG,90,output);output.toByteArray()}
                        // OCR owns and recycles its bitmap; keep the preview frame separately.
                        val text=LabelOCR.readBitmap(context,upright.copy(Bitmap.Config.ARGB_8888,false))
                        if(active.get()) main.execute {if(active.get()) frameCallback(text,codes,bytes)}
                    } finally {upright.recycle()}
                }
            } catch(_:Exception) {if(active.get()) main.execute {if(active.get()) errorCallback()}}
            finally {image.close()}
        }
        future.addListener({if(active.get()) try {
            provider=future.get();provider!!.bindToLifecycle(owner,CameraSelector.DEFAULT_BACK_CAMERA,view,analysis)
        } catch(_:Exception) {errorCallback()}},main)
        onDispose {
            active.set(false);analysis.clearAnalyzer();provider?.unbind(view,analysis);executor.shutdown()
        }
    }
}
