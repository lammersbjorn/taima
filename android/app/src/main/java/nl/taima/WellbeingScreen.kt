package nl.taima

import android.content.SharedPreferences
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.google.gson.*
import kotlinx.coroutines.*

@Composable internal fun WellbeingScreen(prefs:SharedPreferences,bags:List<JsonObject>) {
    val scope=rememberCoroutineScope();var saving by remember {mutableStateOf(false)}
    val context=LocalContext.current
    var answers by rememberSaveable {mutableStateOf(List(8) {-1})}
    var start by rememberSaveable {mutableStateOf(prefs.getString("break.start",null))}
    var checks by remember {mutableStateOf(readHistory(prefs,"selfcheck.history"))}
    var breaks by remember {mutableStateOf(readHistory(prefs,"break.history"))}
    var data by remember {mutableStateOf<JsonObject?>(null)};var failed by remember {mutableStateOf(false)}
    var showCheck by rememberSaveable {mutableStateOf(false)};var result by rememberSaveable {mutableStateOf<Int?>(null)}
    fun keep(key:String,items:List<JsonObject>) {prefs.edit().putString(key,Gson().toJson(items)).apply()}
    LaunchedEffect(answers,start,breaks,bags) {
        failed=false
        try {data=withContext(Dispatchers.Default) {
            val d=Domain.call("dashboard","bags" to bags).asJsonObject
            Domain.call("wellbeing","answers" to answers,"start" to start,"breaks" to breaks,"dailyGrams" to if(start==null) d.number("dailyAverage") else prefs.getFloat("break.pace",0f).toDouble(),"pricePerGram" to if(start==null) d.number("pricePerGram") else prefs.getFloat("break.price",0f).toDouble()).asJsonObject.apply {
                addProperty("pace",d.number("dailyAverage"));addProperty("price",d.number("pricePerGram"))
            }
        }} catch(e:CancellationException) {throw e} catch(_:Exception) {failed=true}
    }
    Page {
        if(failed) Text(stringResource(R.string.operation_failed))
        Text(stringResource(R.string.tolerance_break),style=MaterialTheme.typography.titleLarge)
        if(start==null) Button(enabled=data!=null,onClick={start=timestamp();prefs.edit().putString("break.start",start).putFloat("break.pace",(data?.number("pace") ?: 0.0).toFloat()).putFloat("break.price",(data?.number("price") ?: 0.0).toFloat()).apply()}) {Text(stringResource(R.string.start_break))}
        else {
            data?.let {Metric(R.string.break_days,number(it.number("days")));Metric(R.string.grams_saved,number(it.number("gramsSaved")));Metric(R.string.euros_saved,number(it.number("eurosSaved")))}
            OutlinedButton(onClick={breaks=listOf(obj("start" to start,"end" to timestamp()))+breaks;keep("break.history",breaks);prefs.edit().remove("break.start").apply();start=null}) {Text(stringResource(R.string.end_break))}
        }
        data?.array("breaks")?.forEachIndexed {index,entry ->val b=entry.asJsonObject
            Text("${date(b.text("start"))} · ${date(b.text("end"))}")
            Metric(R.string.break_days,number(b.number("days")))
            TextButton(onClick={breaks=breaks.filterIndexed {i,_ ->i!=index};keep("break.history",breaks)}) {Text(stringResource(R.string.delete_record))}
        }
        HorizontalDivider();Text(stringResource(R.string.self_check_help))
        OutlinedButton(onClick={showCheck=!showCheck}) {Text(stringResource(R.string.self_check))}
        if(showCheck) data?.let {d ->
            if(result==null) {
                d.array("questions").forEachIndexed {index,item ->val question=item.asJsonObject
                    Text(context.coreText(question.text("text")),style=MaterialTheme.typography.titleMedium)
                    question.array("answers").forEachIndexed {answer,text ->
                        Row(Modifier.fillMaxWidth().clickable {answers=answers.toMutableList().apply {set(index,answer)}}.padding(vertical=4.dp)) {
                            RadioButton(answers[index]==answer,{answers=answers.toMutableList().apply {set(index,answer)}})
                            Text(context.coreText(text.asString),Modifier.padding(top=12.dp).weight(1f))
                        }
                    }
                }
                Button(enabled=!answers.contains(-1) && !saving,onClick={saving=true;val chosen=answers.toList();scope.launch {try {
                    val score=withContext(Dispatchers.Default) {Domain.call("wellbeing","answers" to chosen).asJsonObject.number("score")!!.toInt()}
                    result=score;checks=listOf(obj("date" to timestamp(),"score" to score))+checks;keep("selfcheck.history",checks)
                } catch(e:CancellationException) {throw e} catch(_:Exception) {failed=true} finally {saving=false} }}) {Text(stringResource(R.string.see_result))}
            } else {
                Metric(R.string.self_check,"$result / 32");Text(context.coreText(d.text("summary")))
                OutlinedButton(onClick={result=null;answers=List(8) {-1}}) {Text(stringResource(R.string.start_again))}
            }
        }
        checks.forEachIndexed {index,entry ->Text("${date(entry.text("date"))} · ${entry.number("score")?.toInt()} / 32")
            TextButton(onClick={checks=checks.filterIndexed {i,_ ->i!=index};keep("selfcheck.history",checks)}) {Text(stringResource(R.string.delete_record))}
        }
        Text(stringResource(R.string.self_check_citation))
    }
}
private fun readHistory(prefs:SharedPreferences,key:String):List<JsonObject> = runCatching {JsonParser.parseString(prefs.getString(key,"[]")!!).asJsonArray.map {it.asJsonObject}}.getOrDefault(emptyList())
