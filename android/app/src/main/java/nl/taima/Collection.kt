package nl.taima

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.google.gson.JsonObject
import kotlinx.coroutines.*

@Composable internal fun Collection(bags: List<JsonObject>, select:(JsonObject)->Unit) {
    val prefs=LocalContext.current.getSharedPreferences("taima",0)
    var query by rememberSaveable {mutableStateOf("")}
    var sort by rememberSaveable {mutableStateOf(prefs.getString("collection.sort","newest")!!)}
    var grouped by rememberSaveable {mutableStateOf(prefs.getBoolean("collection.grouped",false))}
    var form by rememberSaveable {mutableStateOf("")};var stock by rememberSaveable {mutableStateOf("")}
    var expanded by rememberSaveable {mutableStateOf<String?>(null)}
    var comparing by rememberSaveable {mutableStateOf(false)}
    var chosen by rememberSaveable {mutableStateOf(listOf<String>())}
    var showComparison by remember {mutableStateOf(false)}
    var result by remember {mutableStateOf<JsonObject?>(null)};var error by remember {mutableStateOf(false)}
    LaunchedEffect(bags,query,sort,form,stock) {
        error=false;result=null
        try {result=withContext(Dispatchers.Default) {Domain.call("collection","bags" to bags,"query" to query,"sort" to sort,"form" to form,"stock" to stock).asJsonObject}}
        catch(e:CancellationException) {throw e} catch(_:Exception) {error=true}
    }
    if(bags.isEmpty()) {EmptyState(R.string.no_bags,R.string.no_bags_help);return}
    LazyColumn(contentPadding=PaddingValues(bottom=96.dp)) {
        item {Column(Modifier.padding(16.dp),verticalArrangement=Arrangement.spacedBy(8.dp)) {
            Field(R.string.search,query,{query=it})
            FlowRow(horizontalArrangement=Arrangement.spacedBy(12.dp)) {
                Choice(R.string.sort,sort,listOf("newest" to R.string.newest,"oldest" to R.string.oldest,"strongest" to R.string.strongest,"heaviest" to R.string.heaviest,"name" to R.string.name)) {sort=it;prefs.edit().putString("collection.sort",it).apply()}
                Choice(R.string.form,form,listOf("" to R.string.all,"bag" to R.string.bag,"jar" to R.string.jar,"preroll" to R.string.preroll,"hash" to R.string.hash,"rosin" to R.string.rosin,"edible" to R.string.edibles)){form=it}
                Choice(R.string.stock,stock,listOf("" to R.string.all,"full" to R.string.full,"open" to R.string.open,"empty" to R.string.empty)){stock=it}
            }
            FlowRow(horizontalArrangement=Arrangement.spacedBy(8.dp)) {
                FilterChip(grouped,{grouped=!grouped;prefs.edit().putBoolean("collection.grouped",grouped).apply()},label={Text(stringResource(R.string.by_strain))})
                FilterChip(comparing,{comparing=!comparing;chosen=emptyList()},label={Text(stringResource(R.string.compare))})
                if(comparing) Button(onClick={showComparison=true},enabled=chosen.size==2) {Text(stringResource(R.string.compare_selected))}
            }
            if(comparing) Text(stringResource(R.string.pick_two))
            if(error) Text(stringResource(R.string.operation_failed))
            if(result==null && !error) LinearProgressIndicator(Modifier.fillMaxWidth())
            if(result?.array("bags")?.isEmpty()==true) Text(stringResource(R.string.no_matches))
        }}
        fun toggle(bag:JsonObject) {val id=bag.text("id");chosen=if(id in chosen) chosen-id else if(chosen.size<2) chosen+id else chosen}
        if(grouped) items(result?.array("groups").orEmpty(),key={it.asJsonObject.text("key")}) {row ->val group=row.asJsonObject
            ListItem(headlineContent={Text(group.text("name"))},supportingContent={Text(stringResource(R.string.group_summary,group.array("bags").size,number(group.number("grams"))))},modifier=Modifier.clickable {expanded=if(expanded==group.text("key")) null else group.text("key")})
            if(expanded==group.text("key")) group.array("bags").forEach {b ->val bag=b.asJsonObject;CollectionRow(bag,comparing,bag.text("id") in chosen) {if(comparing) toggle(bag) else select(bag)}}
            HorizontalDivider()
        } else items(result?.array("bags").orEmpty(),key={it.asJsonObject.text("id")}) {row ->val bag=row.asJsonObject
            CollectionRow(bag,comparing,bag.text("id") in chosen) {if(comparing) toggle(bag) else select(bag)};HorizontalDivider()
        }
    }
    if(showComparison) {
        val pair=chosen.mapNotNull {id ->bags.firstOrNull {it.text("id")==id}}
        if(pair.size==2) Comparison(pair[0],pair[1]) {showComparison=false} else showComparison=false
    }
}
@Composable private fun CollectionRow(bag:JsonObject,comparing:Boolean,chosen:Boolean,click:()->Unit) {
    ListItem(headlineContent={Text(bag.text("name"))},supportingContent={Text(bag.text("producer").ifEmpty {stringResource(R.string.unknown)})},
        leadingContent=if(comparing) {{Checkbox(chosen,{click()})}} else null,
        trailingContent={Text(amountLabel(bag,bag.number("grams")))},modifier=Modifier.clickable(onClick=click).heightIn(min=72.dp))
}
@Composable private fun Comparison(left:JsonObject,right:JsonObject,dismiss:()->Unit) {
    androidx.compose.ui.window.Dialog(onDismissRequest=dismiss,properties=androidx.compose.ui.window.DialogProperties(usePlatformDefaultWidth=false)) {
        Surface(Modifier.fillMaxSize()) {Page {
            Text(stringResource(R.string.compare),style=MaterialTheme.typography.headlineSmall)
            TextButton(onClick=dismiss) {Text(stringResource(R.string.back))}
            val lv=remember(left) {Domain.view(left)};val rv=remember(right) {Domain.view(right)}
            @Composable fun row(label:Int,a:String,b:String) {
                Text(stringResource(label),style=MaterialTheme.typography.labelLarge)
                Row(horizontalArrangement=Arrangement.spacedBy(16.dp)) {Text(a,Modifier.weight(1f));Text(b,Modifier.weight(1f))};HorizontalDivider()
            }
            row(R.string.name,left.text("name"),right.text("name"))
            row(R.string.producer,left.text("producer"),right.text("producer"))
            row(R.string.form,LocalContext.current.coreText(left.text("productForm")),LocalContext.current.coreText(right.text("productForm")))
            row(R.string.grams,amountLabel(left,left.number("grams")),amountLabel(right,right.number("grams")))
            row(R.string.thc,number(left.getAsJsonObject("thc")?.number("percent")),number(right.getAsJsonObject("thc")?.number("percent")))
            row(R.string.thc_per_piece,number(left.number("thcMilligrams")),number(right.number("thcMilligrams")))
            row(R.string.cbd,number(left.getAsJsonObject("cbd")?.number("percent")),number(right.getAsJsonObject("cbd")?.number("percent")))
            row(R.string.score,number(lv.number("score")),number(rv.number("score")))
            row(R.string.cure_days,number(lv.number("cureDays")),number(rv.number("cureDays")))
            row(R.string.per_gram,number(lv.number("pricePerGram")),number(rv.number("pricePerGram")))
            row(R.string.packed,left.text("packedOn").take(10),right.text("packedOn").take(10))
            listOf("effects" to R.string.effects,"sideEffects" to R.string.downsides,"flavors" to R.string.flavors).forEach {(key,title) ->row(title,left.array(key).joinToString {it.asString},right.array(key).joinToString {it.asString})}
        }}
    }
}
