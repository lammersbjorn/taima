package nl.taima

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import kotlinx.coroutines.*

@Composable internal fun LearningSettings() {
    val context=LocalContext.current;val prefs=remember {context.getSharedPreferences("taima",0)}
    var enabled by remember {mutableStateOf(prefs.getBoolean("learning.enabled",true))}
    var memory by remember {mutableStateOf(prefs.getString("learning.memory","{\"words\":{}}")!!)}
    Column(verticalArrangement=Arrangement.spacedBy(8.dp)) {
        Row {Switch(enabled,{enabled=it;prefs.edit().putBoolean("learning.enabled",it).apply()});Text(stringResource(R.string.learn_corrections),Modifier.padding(12.dp))}
        Text(stringResource(R.string.learning_help))
        JsonParser.parseString(memory).asJsonObject.getAsJsonObject("words").entrySet().sortedBy {it.key}.forEach {(wrong,right) ->
            Text("$wrong → ${right.asString}")
            TextButton(onClick={
                val result=Domain.call("learning","memory" to JsonParser.parseString(memory),"action" to "forget","word" to wrong).asJsonObject
                memory=result["memory"].toString();prefs.edit().putString("learning.memory",memory).apply()
            }) {Text(stringResource(R.string.forget_correction,wrong))}
        }
    }
}

@Composable internal fun EntryReviewScreen(db:BagDatabase,action:(()->Unit)->Unit) {
    val context=LocalContext.current;val scope=rememberCoroutineScope()
    var busy by remember {mutableStateOf(false)};var failed by remember {mutableStateOf(false)}
    var ran by remember {mutableStateOf(false)}
    var suggestions by remember {mutableStateOf<List<Pair<JsonObject,JsonObject>>>(emptyList())}
    Column(verticalArrangement=Arrangement.spacedBy(12.dp)) {
        Text(stringResource(R.string.review_changes),style=MaterialTheme.typography.titleMedium)
        Button(enabled=!busy,onClick={busy=true;failed=false;scope.launch {
            try {
                suggestions=withContext(Dispatchers.IO) {db.all().mapNotNull {bag ->
                    val bytes=db.photo(bag.text("photoName")) ?: return@mapNotNull null
                    val front=LabelOCR.readBytes(context,bytes)
                    val back=db.photo(bag.text("backPhotoName"))?.let {LabelOCR.readBytes(context,it)}.orEmpty()
                    val type=Domain.core.catalog(name=bag.text("name")).getAsJsonObject("strain")?.text("type")
                    val review=Domain.call("label.review","bag" to bag,"lines" to LabelOCR.lines(front),"backLines" to LabelOCR.lines(back),"libraryType" to type).asJsonObject
                    if(review.array("changes").isEmpty()) null else bag to review
                }};ran=true
            } catch(e:CancellationException) {throw e} catch(_:Exception) {failed=true}
            finally {busy=false}
        }}) {Text(stringResource(R.string.improve_entries))}
        if(busy) LinearProgressIndicator(Modifier.fillMaxWidth())
        if(failed) Text(stringResource(R.string.operation_failed))
        if(ran && suggestions.isEmpty()) Text(stringResource(R.string.no_suggestions))
        suggestions.forEach {(original,review) ->
            Text(original.text("name"),style=MaterialTheme.typography.titleMedium)
            review.array("changes").forEach {change ->val c=change.asJsonObject;Text("${context.coreText(c.text("field"))}: ${c.text("new")}")}
            OutlinedButton(onClick={action {
                db.transaction {db.verifyEditBaseline(original,true);db.put(Domain.call("bag.save","bag" to review.getAsJsonObject("bag")).asJsonObject)}
                suggestions=suggestions.filterNot {it.first.text("id")==original.text("id")}
            }}) {Text(stringResource(R.string.accept_changes))}
        }
    }
}
