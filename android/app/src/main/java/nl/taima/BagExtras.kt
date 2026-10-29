package nl.taima

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.google.gson.JsonObject

@Composable internal fun BagExtras(bag: JsonObject,db: BagDatabase,action: (()->Unit)->Unit,deleted: ()->Unit) {
    val context=LocalContext.current
    var note by rememberSaveable { mutableStateOf("") };var deleting by remember {mutableStateOf(false)}
    var editing by remember {mutableStateOf<JsonObject?>(null)}
    var photo by rememberSaveable {mutableStateOf<String?>(null)}
    val picker=rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) {photo=it?.toString()}
    fun change(op: String, vararg fields: Pair<String,Any?>) { action {db.mutate(bag.text("id")) { fresh ->Domain.call(op,"bag" to fresh,"bags" to db.all(),*fields).asJsonObject}} }
    Column(verticalArrangement=Arrangement.spacedBy(12.dp)) {
        OutlinedButton(onClick={change("bag.repeat")},enabled=Domain.remaining(bag)>0) { Text(stringResource(R.string.repeat_session)) }
        bag.array("usageLog").asReversed().forEach { item ->val entry=item.asJsonObject
            Text("${date(entry.text("date"))} · ${amountLabel(bag,entry.number("grams"))}")
            FlowRow(horizontalArrangement=Arrangement.spacedBy(8.dp)) {
                TextButton(onClick={editing=entry.deepCopy()}) {Text(stringResource(R.string.edit_session))}
                OutlinedButton(onClick={change("bag.undo","id" to entry.text("id"))}) { Text(stringResource(R.string.undo_session)) }
            }
        }
        HorizontalDivider();Field(R.string.notes,note,{note=it})
        OutlinedButton(onClick={picker.launch(androidx.activity.result.PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))}) {Text(stringResource(if(photo==null) R.string.choose_photo else R.string.change_note_photo))}
        if(photo!=null) TextButton(onClick={photo=null}) {Text(stringResource(R.string.remove_photo))}
        OutlinedButton(onClick={
            val text=note;val selectedPhoto=photo
            action {db.transaction {
                val name=selectedPhoto?.let {Photos.store(context,db,android.net.Uri.parse(it))}
                db.mutate(bag.text("id")) {fresh ->Domain.call("bag.note","bag" to fresh,"text" to text,"photoName" to name).asJsonObject}
            };note="";photo=null}
        },enabled=note.isNotBlank() || photo!=null) { Text(stringResource(R.string.add_note)) }
        bag.array("timedNotes").asReversed().forEach {entry ->val n=entry.asJsonObject
            Text(date(n.text("date")));Text(n.text("text"))
            if(n.text("photoName").isNotBlank()) StoredPhoto(n.text("photoName"))
            TextButton(onClick={change("bag.deleteNote","id" to n.text("id"))}) {Text(stringResource(R.string.delete_note))}
        }
        OutlinedButton(onClick={deleting=true}) {Text(stringResource(R.string.delete_bag))}
    }
    editing?.let {entry ->SessionEditor(bag,onDismiss={editing=null},onSave={changed ->change("bag.session","entry" to changed);editing=null},entry=entry)}
    if(deleting) AlertDialog(onDismissRequest={deleting=false},title={Text(stringResource(R.string.delete_bag))},text={Text(stringResource(R.string.delete_confirm))},confirmButton={TextButton(onClick={action { db.delete(bag.text("id"));deleted() };deleting=false}) {Text(stringResource(R.string.delete_bag))}},dismissButton={TextButton(onClick={deleting=false}) {Text(stringResource(R.string.cancel))}})
}
