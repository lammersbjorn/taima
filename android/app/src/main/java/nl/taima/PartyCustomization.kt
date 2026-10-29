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

@Composable internal fun PartyCustomization(settings:JsonObject,save:(JsonObject)->Unit,reset:(String)->Unit) {
    var editing by remember {mutableStateOf<JsonObject?>(null)}
    var wayName by rememberSaveable {mutableStateOf("")}
    var category by rememberSaveable {mutableStateOf("")}
    var letters by rememberSaveable {mutableStateOf(settings.text("letters"))}
    var confirm by remember {mutableStateOf<String?>(null)}
    Text(stringResource(R.string.house_rules),style=MaterialTheme.typography.titleLarge)
    settings.array("cards").forEach {item ->val card=item.asJsonObject
        Row {
            Checkbox(card["enabled"].asBoolean,{on ->save(settings.deepCopy().apply {array("cards").first {it.asJsonObject.text("id")==card.text("id")}.asJsonObject.addProperty("enabled",on)})})
            TaimaTextButton(onClick={editing=card.deepCopy()}) {Text(card.text("title"))}
        }
    }
    TaimaOutlinedButton(onClick={editing=obj("id" to java.util.UUID.randomUUID().toString(),"title" to "","detail" to "","kind" to "rule","minPlayers" to 1,"intense" to false,"enabled" to true,"builtIn" to false,"dealsPrompt" to false)}) {Text(stringResource(R.string.add_rule))}
    Field(R.string.way_name,wayName,{wayName=it})
    TaimaOutlinedButton(enabled=wayName.isNotBlank(),onClick={save(settings.deepCopy().apply {getAsJsonArray("ways").add(obj("id" to java.util.UUID.randomUUID().toString(),"name" to wayName.trim(),"symbol" to "flame","enabled" to true,"builtIn" to false))});wayName=""}) {Text(stringResource(R.string.add_way))}
    settings.array("ways").filter {!it.asJsonObject["builtIn"].asBoolean}.forEach {item ->val way=item.asJsonObject
        TaimaTextButton(onClick={save(settings.deepCopy().apply {add("ways",com.google.gson.JsonArray().also {out ->array("ways").filter {it.asJsonObject.text("id")!=way.text("id")}.forEach {out.add(it)}})})}) {Text(stringResource(R.string.remove_named,way.text("name")))}
    }
    Field(R.string.letters,letters,{letters=it})
    TaimaTextButton(onClick={save(settings.deepCopy().apply {addProperty("letters",letters)})}) {Text(stringResource(R.string.save))}
    settings.array("categories").forEach {item ->TaimaTextButton(onClick={save(settings.deepCopy().apply {add("categories",com.google.gson.JsonArray().also {out ->array("categories").filter {it.asString!=item.asString}.forEach {out.add(it)}})})}) {Text(stringResource(R.string.remove_named,item.asString))}}
    Field(R.string.category,category,{category=it})
    TaimaOutlinedButton(enabled=category.isNotBlank(),onClick={save(settings.deepCopy().apply {getAsJsonArray("categories").add(category.trim())});category=""}) {Text(stringResource(R.string.add_category))}
    Text(stringResource(R.string.legendary_frequency))
    Slider(value=(settings.number("legendaryChanceSetting") ?: (1.0/15)).toFloat().coerceIn(0f,0.25f),onValueChange={n ->save(settings.deepCopy().apply {addProperty("legendaryChanceSetting",n)})},valueRange=0f..0.25f)
    listOf("resetNight" to R.string.reset_night,"resetSeen" to R.string.reset_seen,"resetDefaults" to R.string.restore_defaults).forEach {(key,title) ->TaimaOutlinedButton(onClick={confirm=key}) {Text(stringResource(title))}}
    confirm?.let {op ->AlertDialog(onDismissRequest={confirm=null},title={Text(stringResource(R.string.reset_party))},text={Text(stringResource(R.string.reset_party_help))},confirmButton={TaimaTextButton(onClick={confirm=null;reset(op)}) {Text(stringResource(R.string.restore))}},dismissButton={TaimaTextButton(onClick={confirm=null}) {Text(stringResource(R.string.cancel))}})}
    editing?.let {original ->
        var title by remember(original) {mutableStateOf(original.text("title"))};var details by remember(original) {mutableStateOf(original.text("detail"))}
        var kind by remember(original) {mutableStateOf(original.text("kind"))};var players by remember(original) {mutableStateOf((original.number("minPlayers") ?: 1.0).toInt().toString())}
        var intense by remember(original) {mutableStateOf(original.text("intense")=="true")};var legendary by remember(original) {mutableStateOf(original.text("legendaryFlag")=="true")}
        AlertDialog(onDismissRequest={editing=null},title={Text(stringResource(R.string.house_rules))},text={Column(Modifier.verticalScroll(rememberScrollState()),verticalArrangement=Arrangement.spacedBy(8.dp)) {
            Field(R.string.name,title,{title=it});OutlinedTextField(details,{details=it},label={Text(stringResource(R.string.instructions))},minLines=4)
            Choice(R.string.rule_kind,kind,listOf("game" to R.string.game,"rule" to R.string.table_rule)){kind=it}
            Field(R.string.minimum_players,players,{players=it},true)
            Row {Checkbox(intense,{intense=it});Text(stringResource(R.string.intense))};Row {Checkbox(legendary,{legendary=it});Text(stringResource(R.string.legendary))}
            if(original.text("builtIn")=="false") TaimaTextButton(onClick={save(settings.deepCopy().apply {add("cards",com.google.gson.JsonArray().also {out ->array("cards").filter {it.asJsonObject.text("id")!=original.text("id")}.forEach {out.add(it)}})});editing=null}) {Text(stringResource(R.string.delete_rule))}
        }},confirmButton={TaimaTextButton(enabled=title.isNotBlank() && details.isNotBlank() && players.toIntOrNull()?.let {it in 1..100}==true,onClick={
            val changed=original.deepCopy().apply {addProperty("title",title.trim());addProperty("detail",details.trim());addProperty("kind",kind);addProperty("minPlayers",players.toInt());addProperty("intense",intense);addProperty("legendaryFlag",legendary)}
            save(settings.deepCopy().apply {add("cards",com.google.gson.JsonArray().also {out ->array("cards").filter {it.asJsonObject.text("id")!=changed.text("id")}.forEach {out.add(it)};out.add(changed)})});editing=null
        }) {Text(stringResource(R.string.save))}},dismissButton={TaimaTextButton(onClick={editing=null}) {Text(stringResource(R.string.cancel))}})
    }
}
