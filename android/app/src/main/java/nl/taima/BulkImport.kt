package nl.taima

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.google.gson.JsonObject
import kotlinx.coroutines.*

/** Read sequentially and keep only staged photos, never a collection of decoded bitmaps. */
@Composable internal fun BulkImport(enabled:Boolean,mode:String?,consumed:()->Unit,onDrafts:(List<JsonObject>)->Unit) {
    val context=LocalContext.current;val scope=rememberCoroutineScope()
    var paired by remember {mutableStateOf(false)}
    var busy by remember {mutableStateOf(false)}
    var progress by remember {mutableIntStateOf(0)}
    var failed by remember {mutableIntStateOf(0)}
    val picker=rememberLauncherForActivityResult(ActivityResultContracts.PickMultipleVisualMedia(80)) {uris ->
        if(uris.isNotEmpty()) {val pairs=paired;busy=true;failed=0;progress=0
            scope.launch {
                val drafts=mutableListOf<JsonObject>()
                try {
                    withContext(Dispatchers.IO) {
                        var index=0
                        while(index<uris.size) {
                            val staged=mutableListOf<java.io.File>()
                            try {
                                val front=Photos.stage(context,uris[index]).also(staged::add)
                                val text=LabelOCR.read(context,android.net.Uri.fromFile(front))
                                var bag=Domain.call("label","lines" to LabelOCR.lines(text)).asJsonObject.getAsJsonObject("bag")
                                bag.addProperty("androidDraftPhoto",front.toURI().toString())
                                if(pairs && index+1<uris.size) {
                                    val back=Photos.stage(context,uris[index+1]).also(staged::add)
                                    val backText=LabelOCR.read(context,android.net.Uri.fromFile(back))
                                    val photo=bag.text("androidDraftPhoto")
                                    bag=Domain.call("label","bag" to bag,"lines" to LabelOCR.lines(backText),"back" to true).asJsonObject.getAsJsonObject("bag")
                                    bag.addProperty("androidDraftPhoto",photo);bag.addProperty("androidBackPhoto",back.toURI().toString())
                                }
                                drafts.add(LabelLearning.apply(context,bag));staged.clear()
                            } catch(e:CancellationException) {throw e} catch(_:Exception) {withContext(Dispatchers.Main) {failed++}}
                            finally {staged.forEach {it.delete()}}
                            index+=if(pairs) 2 else 1
                            withContext(Dispatchers.Main) {progress=index.coerceAtMost(uris.size)}
                        }
                    }
                    onDrafts(drafts)
                } finally {if(!isActive) drafts.forEach {Photos.clearDraft(context,it)};busy=false}
            }
        }
    }
    LaunchedEffect(mode) {
        if(mode!=null && enabled && !busy) {
            paired=mode=="paired"
            picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
            consumed()
        }
    }
    if(busy || failed>0) Column(Modifier.padding(16.dp)) {
        if(busy) {LinearProgressIndicator(Modifier.fillMaxWidth());Text(stringResource(R.string.import_progress,progress))}
        if(failed>0) Text(stringResource(R.string.import_failed_count,failed))
    }
}
