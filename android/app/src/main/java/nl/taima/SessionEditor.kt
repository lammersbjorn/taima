package nl.taima

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.google.gson.JsonObject

/** Editing changes session details only; the core preserves its amount and identity. */
@Composable internal fun SessionEditor(bag:JsonObject,onDismiss:()->Unit,onSave:(JsonObject)->Unit,entry:JsonObject?=null) {
    val methods=remember(bag) {Domain.view(bag).array("methods").map {it.asString}}
    var amount by rememberSaveable { mutableStateOf(entry?.number("grams")?.let(::number).orEmpty()) }
    var note by rememberSaveable { mutableStateOf(entry?.text("note").orEmpty()) }
    var method by rememberSaveable { mutableStateOf(entry?.text("method")?.takeIf(String::isNotBlank) ?: methods.first()) }
    var before by rememberSaveable { mutableStateOf(entry?.number("moodBefore")?.toInt()?.toString().orEmpty()) }
    var after by rememberSaveable {mutableStateOf(entry?.number("moodAfter")?.toInt()?.toString().orEmpty())}
    var tobacco by rememberSaveable {mutableStateOf(entry?.text("withTobacco")=="true")}
    var whenText by rememberSaveable {mutableStateOf(entry?.text("date") ?: timestamp())}
    var error by remember {mutableStateOf(false)}
    AlertDialog(onDismissRequest=onDismiss,title={Text(stringResource(if(entry==null) R.string.log_session else R.string.edit_session))},text={
        Column(Modifier.verticalScroll(rememberScrollState()),verticalArrangement=Arrangement.spacedBy(12.dp)) {
            if(entry==null) Field(if(isEdible(bag)) R.string.pieces else R.string.amount,amount,{amount=it},true)
            else Text(amountLabel(bag,entry.number("grams")))
            Choice(R.string.method,method,(methods+listOf(method)).distinct().map {it to methodLabel(it)}){method=it}
            Field(R.string.session_date,whenText,{whenText=it})
            Field(R.string.notes,note,{note=it});Field(R.string.mood_before,before,{before=it},true);Field(R.string.mood_after,after,{after=it},true)
            Row {Checkbox(tobacco,{tobacco=it});Text(stringResource(R.string.with_tobacco),Modifier.padding(top=12.dp))}
            if(error) Text(stringResource(R.string.invalid_fields),color=MaterialTheme.colorScheme.error)
        }
    },confirmButton={TextButton(onClick={
        val n=if(entry==null) Domain.amount(amount) else entry.number("grams")
        val date=runCatching {java.time.Instant.parse(whenText).toString()}.getOrNull()
        if(n==null || n<=0 || (entry==null && n>Domain.remaining(bag)) || date==null || listOf(before,after).any {it.isNotBlank() && it.toIntOrNull()?.let {v -> v in 1..5} != true}) error=true
        else if(entry==null) onSave(obj("amount" to n,"method" to method,"note" to note,"now" to date,"moodBefore" to before.toIntOrNull(),"moodAfter" to after.toIntOrNull(),"withTobacco" to tobacco))
        else onSave(entry.deepCopy().apply {
            addProperty("method",method);addProperty("note",note);addProperty("date",date);addProperty("withTobacco",tobacco)
            remove("moodBefore");remove("moodAfter");before.toIntOrNull()?.let {addProperty("moodBefore",it)};after.toIntOrNull()?.let {addProperty("moodAfter",it)}
        })
    }){Text(stringResource(R.string.save))}},dismissButton={TextButton(onClick=onDismiss){Text(stringResource(R.string.cancel))}})
}
