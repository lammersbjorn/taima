package nl.taima

import androidx.compose.foundation.Image
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.google.gson.JsonObject
import kotlinx.coroutines.*
import java.io.File

@Composable internal fun ItemShareSheet(bag:JsonObject,dismiss:()->Unit) {
    val context=LocalContext.current
    var file by remember {mutableStateOf<File?>(null)}
    var image by remember {mutableStateOf<android.graphics.Bitmap?>(null)}
    var failed by remember {mutableStateOf(false)}
    LaunchedEffect(bag) {
        try {val rendered=withContext(Dispatchers.IO) {ShareCards.renderItem(context,bag)};file=rendered;image=withContext(Dispatchers.IO) {Photos.decode(rendered.readBytes(),2)}}
        catch(e:CancellationException) {throw e} catch(_:Exception) {failed=true}
    }
    DisposableEffect(Unit) {onDispose {image?.recycle()}}
    AlertDialog(onDismissRequest=dismiss,title={Text(stringResource(R.string.share_card))},text={Column(Modifier.verticalScroll(rememberScrollState()),verticalArrangement=Arrangement.spacedBy(12.dp)) {
        image?.let {Image(it.asImageBitmap(),stringResource(R.string.share_card),Modifier.fillMaxWidth().heightIn(max=360.dp))}
        if(image==null && !failed) CircularProgressIndicator()
        if(failed) Text(stringResource(R.string.operation_failed))
        Text(stringResource(R.string.share_privacy))
    }},confirmButton={TextButton(enabled=file!=null,onClick={file?.let {ShareCards.send(context,it)}}) {Text(stringResource(R.string.share_card))}},dismissButton={TextButton(onClick=dismiss) {Text(stringResource(R.string.done))}})
}
