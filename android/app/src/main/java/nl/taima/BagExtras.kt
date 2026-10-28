package nl.taima

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.google.gson.JsonObject

@Composable internal fun BagExtras(bag: JsonObject,db: BagDatabase,action: (()->Unit)->Unit,deleted: ()->Unit) {
    var note by rememberSaveable { mutableStateOf("") };var deleting by remember {mutableStateOf(false)}
    fun change(op: String, vararg fields: Pair<String,Any?>) { action {db.mutate(bag.text("id")) { fresh ->Domain.call(op,"bag" to fresh,"bags" to db.all(),*fields).asJsonObject}} }
    Column(Modifier.padding(20.dp),verticalArrangement=Arrangement.spacedBy(12.dp)) {
        OutlinedButton(onClick={change("bag.repeat")},enabled=Domain.remaining(bag)>0) { Text(stringResource(R.string.repeat_session)) }
        bag.array("usageLog").asReversed().forEach { item ->val entry=item.asJsonObject
            Text("${date(entry.text("date"))} · ${number(entry.number("grams"))} g")
            OutlinedButton(onClick={change("bag.undo","id" to entry.text("id"))}) { Text(stringResource(R.string.undo_session)) }
        }
        HorizontalDivider();Field(R.string.notes,note,{note=it})
        OutlinedButton(onClick={change("bag.note","text" to note);note=""},enabled=note.isNotBlank()) { Text(stringResource(R.string.add_note)) }
        bag.array("timedNotes").asReversed().forEach {entry ->val n=entry.asJsonObject;Text(date(n.text("date")));Text(n.text("text"))}
        OutlinedButton(onClick={deleting=true}) {Text(stringResource(R.string.delete_bag))}
    }
    if(deleting) AlertDialog(onDismissRequest={deleting=false},title={Text(stringResource(R.string.delete_bag))},text={Text(stringResource(R.string.delete_confirm))},confirmButton={TextButton(onClick={action { db.delete(bag.text("id"));deleted() };deleting=false}) {Text(stringResource(R.string.delete_bag))}},dismissButton={TextButton(onClick={deleting=false}) {Text(stringResource(R.string.cancel))}})
}
