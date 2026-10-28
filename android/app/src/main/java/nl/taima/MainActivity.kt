package nl.taima

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.enableEdgeToEdge
import androidx.activity.compose.setContent
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.*
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.*
import androidx.compose.ui.unit.dp
import com.google.gson.*
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import nl.taima.core.*
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) { super.onCreate(savedInstanceState); enableEdgeToEdge(); setContent { TaimaTheme { Taima() } } }
}
@Composable private fun TaimaTheme(content: @Composable () -> Unit) {
    val scheme = if (isSystemInDarkTheme()) darkColorScheme(primary=Color(0xFF85D5A4),onPrimary=Color(0xFF00391B),surface=Color(0xFF141714),surfaceContainer=Color(0xFF202420),secondary=Color(0xFFBBC5BB),onSecondaryContainer=Color(0xFFE3E8E1),secondaryContainer=Color(0xFF303630))
    else lightColorScheme(primary=Color(0xFF1B7A47),onPrimary=Color.White,surface=Color(0xFFF8FAF6),surfaceContainer=Color(0xFFEEF1EB),secondary=Color(0xFF516151),onSecondaryContainer=Color(0xFF182018),secondaryContainer=Color(0xFFE2E8DE))
    MaterialTheme(colorScheme=scheme,content=content)
}
private val destinations = listOf(R.string.collection, R.string.stash, R.string.stats, R.string.play, R.string.settings)
private val icons = listOf(Icons.Default.Inventory2, Icons.Default.Grass, Icons.Default.BarChart, Icons.Default.Style, Icons.Default.Settings)
@OptIn(ExperimentalMaterial3Api::class)
@Composable private fun Taima() {
    val context = LocalContext.current
    val db = remember { BagDatabase(context) }
    DisposableEffect(db) { onDispose { db.close() } }
    val prefs = remember { context.getSharedPreferences("taima",0) }
    var inUse by rememberSaveable { mutableStateOf(prefs.getString("inUse",null)) }
    var bags by remember { mutableStateOf<List<JsonObject>>(emptyList()) }
    var page by rememberSaveable { mutableIntStateOf(0) }
    var detail by rememberSaveable { mutableStateOf<String?>(null) }
    var editing by remember { mutableStateOf<JsonObject?>(null) }
    var logging by remember { mutableStateOf<JsonObject?>(null) }
    var busy by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope(); val mutex = remember { Mutex() }; val snackbar = remember { SnackbarHostState() }
    val failed = stringResource(R.string.operation_failed); val done = stringResource(R.string.done)
    fun action(block: () -> Unit) { if(busy) return; busy=true; scope.launch {
        try { val next = withContext(Dispatchers.IO) { mutex.withLock { block(); db.all() } }; bags=next }
        catch (_: Exception) { snackbar.showSnackbar(failed) }
        finally { busy=false }
    } }
    LaunchedEffect(Unit) { action {} }
    val selected = bags.find { it.text("id") == detail }
    BackHandler(detail != null || editing != null || logging != null) { if(editing != null) editing=null else if(logging != null) logging=null else detail=null }
    val wide = LocalConfiguration.current.screenWidthDp >= 600
    Scaffold(
        topBar = { TopAppBar(title = { Text(if(editing != null) stringResource(R.string.edit_bag) else selected?.text("name") ?: stringResource(destinations[page]), maxLines=2) }, navigationIcon = { if(detail != null) IconButton(onClick={detail=null}) { Icon(Icons.AutoMirrored.Filled.ArrowBack,stringResource(R.string.back)) } }) },
        bottomBar = { if(!wide) NavigationBar { destinations.forEachIndexed { i, title -> NavigationBarItem(selected=page==i,onClick={page=i; detail=null},icon={Icon(icons[i],null)},label={Text(stringResource(title))}) } } },
        floatingActionButton = { if(page==0 && detail==null) FloatingActionButton(onClick={editing=Records.newBag()}) { Icon(Icons.Default.Add,stringResource(R.string.add_bag)) } },
        snackbarHost = { SnackbarHost(snackbar) }
    ) { padding ->
        Row(Modifier.fillMaxSize().padding(padding)) {
            if(wide) NavigationRail { destinations.forEachIndexed { i,title -> NavigationRailItem(selected=page==i,onClick={page=i;detail=null},icon={Icon(icons[i],null)},label={Text(stringResource(title))}) } }
            Column(Modifier.weight(1f)) {
                if(busy) LinearProgressIndicator(Modifier.fillMaxWidth())
                when {
                    selected != null -> BagDetail(selected, onEdit={editing=selected.deepCopy()}, onUse={inUse=selected.text("id");prefs.edit().putString("inUse",inUse).apply();detail=null;page=1}, onLog={logging=selected})
                    page == 0 -> Collection(bags) { detail=it.text("id") }
                    page == 1 -> {
                        val bag = bags.find { it.text("id")==inUse }
                        if(bag==null) EmptyState(R.string.no_stash,R.string.no_stash_help)
                        else Stash(bag, !busy, { amount -> action { val fresh=db.all().first { it.text("id")==bag.text("id") }; db.put(Records.log(fresh,amount,"other","")) } }, { logging=bag })
                    }
                    page == 2 -> Stats(bags)
                    page == 3 -> Party()
                    page == 4 -> Settings(db, busy, ::action) { scope.launch { snackbar.showSnackbar(done) } }
                }
            }
        }
    }
    editing?.let { bag -> Editor(bag, onDismiss={editing=null}) { edited -> action { db.put(edited) }; editing=null } }
    logging?.let { bag -> SessionEditor(bag,onDismiss={logging=null}) { amount, method, note -> action { val fresh=db.all().first { it.text("id")==bag.text("id") }; db.put(Records.log(fresh,amount,method,note)) };logging=null } }
}
@Composable private fun EmptyState(title:Int, body:Int) { Column(Modifier.padding(24.dp),verticalArrangement=Arrangement.spacedBy(12.dp)) { Text(stringResource(title),style=MaterialTheme.typography.headlineSmall);Text(stringResource(body),color=MaterialTheme.colorScheme.onSurfaceVariant) } }
@Composable private fun Collection(bags: List<JsonObject>, select:(JsonObject)->Unit) {
    var query by rememberSaveable { mutableStateOf("") }
    if(bags.isEmpty()) EmptyState(R.string.no_bags,R.string.no_bags_help)
    else LazyColumn(contentPadding=PaddingValues(bottom=96.dp)) {
        item { OutlinedTextField(query,{query=it},label={Text(stringResource(R.string.search))},singleLine=true,modifier=Modifier.fillMaxWidth().padding(16.dp)) }
        items(bags.filter { it.text("name").contains(query,true) || it.text("producer").contains(query,true) },key={it.text("id")}) { bag ->
            ListItem(headlineContent={Text(bag.text("name"))},supportingContent={Text(bag.text("producer").ifEmpty { stringResource(R.string.unknown) })},trailingContent={Text("${number(bag.number("grams"))} g",fontFamily=FontFamily.Monospace)},modifier=Modifier.clickable { select(bag) }.heightIn(min=72.dp)); HorizontalDivider()
        }
    }
}
@Composable private fun BagDetail(bag:JsonObject,onEdit:()->Unit,onUse:()->Unit,onLog:()->Unit) {
    Column(Modifier.verticalScroll(rememberScrollState()).padding(20.dp),verticalArrangement=Arrangement.spacedBy(16.dp)) {
        Text(bag.text("producer"),style=MaterialTheme.typography.titleMedium)
        Metric(R.string.grams,"${number(bag.number("grams"))} g");Metric(R.string.thc,bag.getAsJsonObject("thc")?.number("percent")?.let { "${number(it)}%" } ?: stringResource(R.string.unknown))
        Text(bag.text("notes"))
        Button(onClick=onUse,enabled=Records.remaining(bag)>0) { Text(stringResource(R.string.use_bag)) }
        Row(horizontalArrangement=Arrangement.spacedBy(12.dp)) { OutlinedButton(onClick=onEdit) { Text(stringResource(R.string.edit_bag)) }; OutlinedButton(onClick=onLog,enabled=Records.remaining(bag)>0) { Text(stringResource(R.string.log_session)) } }
        Sessions(bag)
    }
}
@Composable private fun Stash(bag:JsonObject,enabled:Boolean,quick:(Double)->Unit,session:()->Unit) {
    Column(Modifier.verticalScroll(rememberScrollState()).padding(20.dp),verticalArrangement=Arrangement.spacedBy(16.dp)) {
        Text(stringResource(R.string.in_use),style=MaterialTheme.typography.titleMedium)
        Text(bag.text("name"),style=MaterialTheme.typography.headlineMedium)
        Metric(R.string.remaining,"${number(Records.remaining(bag))} g")
        FlowRow(horizontalArrangement=Arrangement.spacedBy(8.dp)) { listOf(0.1,0.25,0.5).forEach { amount -> OutlinedButton(onClick={quick(amount)},enabled=enabled && amount<=Records.remaining(bag)) { Text("${number(amount)} g") } } }
        Button(onClick=session,enabled=enabled && Records.remaining(bag)>0) { Text(stringResource(R.string.log_session)) }
        Sessions(bag)
    }
}
@Composable private fun Sessions(bag:JsonObject) {
    Text(stringResource(R.string.session_log),style=MaterialTheme.typography.titleLarge)
    val sessions = bag.getAsJsonArray("usageLog")?.toList().orEmpty()
    if(sessions.isEmpty()) Text(stringResource(R.string.no_sessions))
    sessions.asReversed().forEach { element -> val entry=element.asJsonObject
        HorizontalDivider();Text("${number(entry.number("grams"))} g · ${date(entry.text("date"))}",style=MaterialTheme.typography.bodyLarge)
        Text("${stringResource(methodLabel(entry.text("method")))} ${entry.text("note")}",color=MaterialTheme.colorScheme.onSurfaceVariant)
    }
}
@Composable private fun Stats(bags:List<JsonObject>) {
    val sessions=bags.flatMap { it.getAsJsonArray("usageLog")?.toList().orEmpty() }
    Column(Modifier.verticalScroll(rememberScrollState()).padding(20.dp),verticalArrangement=Arrangement.spacedBy(20.dp)) {
        Text(pluralStringResource(R.plurals.item_count,bags.size,bags.size),style=MaterialTheme.typography.headlineMedium)
        Metric(R.string.total_weight,"${number(bags.sumOf { it.number("grams") ?: 0.0 })} g")
        Metric(R.string.stash_weight,"${number(bags.sumOf(Records::remaining))} g")
        Metric(R.string.sessions,sessions.size.toString());Metric(R.string.used_weight,"${number(sessions.sumOf { it.asJsonObject.number("grams") ?: 0.0 })} g")
        val thc=bags.filter { it.text("productForm")!="hash" }.mapNotNull { it.getAsJsonObject("thc")?.number("percent") }
        Metric(R.string.average_thc,if(thc.isEmpty()) stringResource(R.string.unknown) else "${number(thc.average())}%")
        Metric(R.string.growers,bags.map { it.text("producer") }.filter(String::isNotBlank).distinct().size.toString())
    }
}
@Composable private fun Metric(label:Int,value:String) { Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween) { Text(stringResource(label),modifier=Modifier.weight(1f));Text(value,style=MaterialTheme.typography.titleMedium,fontFamily=FontFamily.Monospace) } }
private fun number(value:Double?):String = value?.let { java.text.NumberFormat.getNumberInstance().apply { maximumFractionDigits=2;isGroupingUsed=false }.format(it) } ?: "—"
private fun date(value:String):String = runCatching { DateTimeFormatter.ofLocalizedDateTime(FormatStyle.SHORT).withZone(ZoneId.systemDefault()).format(Instant.parse(value)) }.getOrDefault(value)
private fun methodLabel(method:String) = when(method) { "joint"->R.string.joint;"vape"->R.string.vape;"bong"->R.string.bong;"pipe"->R.string.pipe;"edible"->R.string.edible;else->R.string.other }
@OptIn(ExperimentalMaterial3Api::class)
@Composable private fun Editor(original:JsonObject,onDismiss:()->Unit,onSave:(JsonObject)->Unit) {
    var name by rememberSaveable { mutableStateOf(original.text("name")) };var producer by rememberSaveable { mutableStateOf(original.text("producer")) }
    var grams by rememberSaveable { mutableStateOf(original.number("grams")?.let(::number) ?: "") };var remaining by rememberSaveable { mutableStateOf(original.number("remainingGrams")?.let(::number) ?: "") }
    var thc by rememberSaveable { mutableStateOf(original.getAsJsonObject("thc")?.number("percent")?.let(::number) ?: "") };var cbd by rememberSaveable { mutableStateOf(original.getAsJsonObject("cbd")?.number("percent")?.let(::number) ?: "") }
    var price by rememberSaveable { mutableStateOf(original.number("priceEuros")?.let(::number) ?: "") };var score by rememberSaveable { mutableStateOf(original.number("score")?.let(::number) ?: "") }
    var notes by rememberSaveable { mutableStateOf(original.text("notes")) };var form by rememberSaveable { mutableStateOf(original.text("productForm").ifEmpty { "bag" }) };var stock by rememberSaveable { mutableStateOf(original.text("stockState").ifEmpty { "empty" }) }
    var error by remember { mutableStateOf(false) }
    androidx.compose.ui.window.Dialog(onDismissRequest=onDismiss,properties=androidx.compose.ui.window.DialogProperties(usePlatformDefaultWidth=false)) {
        Surface(Modifier.fillMaxSize()) { Scaffold(topBar={TopAppBar(title={Text(stringResource(R.string.edit_bag))},navigationIcon={IconButton(onClick=onDismiss){Icon(Icons.AutoMirrored.Filled.ArrowBack,stringResource(R.string.cancel))}})},bottomBar={ Surface { Button(onClick={
            val locale=Locale.getDefault(); fun parse(s:String)=AmountInput.parse(s,locale)
            val fields=listOf(grams,remaining,thc,cbd,price,score)
            val valid=fields.all { it.isBlank() || parse(it)!=null } && listOf(thc,cbd).all { it.isBlank() || parse(it)!!<=100 } && (score.isBlank() || parse(score)!!<=10)
            val bag=original.deepCopy()
            if(!valid || name.isBlank()) { error=true; return@Button }
            bag.addProperty("name",name.trim());bag.addProperty("producer",producer);bag.addProperty("notes",notes);bag.addProperty("productForm",form);bag.addProperty("stockState",stock)
            mapOf("grams" to grams,"priceEuros" to price,"score" to score).forEach { (key,value) -> if(value.isBlank()) bag.remove(key) else bag.addProperty(key,parse(value)) }
            val rest=when(stock) { "full"->parse(grams);"empty"->0.0;else->parse(remaining) ?: parse(grams) }
            if(rest==null) bag.remove("remainingGrams") else bag.addProperty("remainingGrams",rest)
            mapOf("thc" to thc,"cbd" to cbd).forEach { (key,value) -> if(value.isBlank()) bag.remove(key) else {
                // Preserve upper-bound / basis metadata when the potency has not changed.
                if(original.getAsJsonObject(key)?.number("percent") != parse(value)) bag.add(key,JsonObject().apply { addProperty("percent",parse(value));addProperty("isUpperBound",false) })
            } }
            bag.addProperty("updatedAt",Records.timestamp())
            if(runCatching { Records.validate(bag) }.isSuccess) onSave(bag) else error=true
        },modifier=Modifier.fillMaxWidth().padding(16.dp)) { Text(stringResource(R.string.save)) } } }) { padding ->
            Column(Modifier.padding(padding).imePadding().verticalScroll(rememberScrollState()).padding(20.dp),verticalArrangement=Arrangement.spacedBy(12.dp)) {
                Field(R.string.name,name,{name=it});Field(R.string.producer,producer,{producer=it})
                Choice(R.string.form,form,listOf("bag" to R.string.bag,"jar" to R.string.jar,"preroll" to R.string.preroll,"hash" to R.string.hash)){form=it}
                Choice(R.string.stock,stock,listOf("full" to R.string.full,"open" to R.string.open,"empty" to R.string.empty)){stock=it}
                Field(R.string.grams,grams,{grams=it},true);if(stock=="open") Field(R.string.remaining,remaining,{remaining=it},true)
                Field(R.string.thc,thc,{thc=it},true);Field(R.string.cbd,cbd,{cbd=it},true);Field(R.string.price,price,{price=it},true);Field(R.string.score,score,{score=it},true)
                OutlinedTextField(notes,{notes=it},label={Text(stringResource(R.string.notes))},modifier=Modifier.fillMaxWidth(),minLines=3)
                if(error) Text(stringResource(R.string.invalid_fields),color=MaterialTheme.colorScheme.error)
            }
        } }
    }
}
@Composable private fun Field(label:Int,value:String,change:(String)->Unit,numeric:Boolean=false) { OutlinedTextField(value,change,label={Text(stringResource(label))},singleLine=true,keyboardOptions=KeyboardOptions(keyboardType=if(numeric) KeyboardType.Decimal else KeyboardType.Text),modifier=Modifier.fillMaxWidth()) }
@Composable private fun Choice(label:Int,value:String,options:List<Pair<String,Int>>,change:(String)->Unit) {
    var expanded by remember { mutableStateOf(false) }
    Column { Text(stringResource(label),style=MaterialTheme.typography.labelLarge)
        Box { OutlinedButton(onClick={expanded=true}) { Text(stringResource(options.firstOrNull { it.first==value }?.second ?: options.first().second)) }
            DropdownMenu(expanded,{expanded=false}) { options.forEach { (key,title) -> DropdownMenuItem(text={Text(stringResource(title))},onClick={change(key);expanded=false}) } }
        }
    }
}
@Composable private fun SessionEditor(bag:JsonObject,onDismiss:()->Unit,onSave:(Double,String,String)->Unit) {
    var amount by rememberSaveable { mutableStateOf("") };var note by rememberSaveable { mutableStateOf("") };var method by rememberSaveable { mutableStateOf("vape") };var error by remember { mutableStateOf(false) }
    AlertDialog(onDismissRequest=onDismiss,title={Text(stringResource(R.string.log_session))},text={Column(Modifier.verticalScroll(rememberScrollState()),verticalArrangement=Arrangement.spacedBy(12.dp)) {
        Field(R.string.amount,amount,{amount=it},true);Choice(R.string.method,method,listOf("joint","vape","bong","pipe","edible","other").map { it to methodLabel(it) }){method=it}
        Field(R.string.notes,note,{note=it});if(error) Text(stringResource(R.string.invalid_fields),color=MaterialTheme.colorScheme.error)
    }},confirmButton={TextButton(onClick={val n=AmountInput.parse(amount,Locale.getDefault());if(n==null || n<=0 || n>Records.remaining(bag)) error=true else onSave(n,method,note)}){Text(stringResource(R.string.save))}},dismissButton={TextButton(onClick=onDismiss){Text(stringResource(R.string.cancel))}})
}
@Composable private fun Settings(db:BagDatabase,busy:Boolean,action:(()->Unit)->Unit,done:()->Unit) {
    val context=LocalContext.current
    var passphrase by remember { mutableStateOf("") }
    var pending by remember { mutableStateOf<android.net.Uri?>(null) }
    val export=rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/octet-stream")) { uri -> uri?.let { val phrase=passphrase;action { context.contentResolver.openOutputStream(it)?.use { output -> Archive.write(output,Archive.Backup(db.snapshot(),db.photos()),phrase) } ?: error("No output");done() } } }
    val import=rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { pending=it }
    val csvExport=rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/csv")) { uri -> uri?.let { action { context.contentResolver.openOutputStream(it)?.bufferedWriter()?.use { output -> output.write(CSV.make(db.all())) } ?: error("No output");done() } } }
    val csvImport=rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri -> uri?.let { action {
        val text=context.contentResolver.openInputStream(it)?.bufferedReader()?.use { reader -> val out=StringBuilder();val chunk=CharArray(8192);while(true) { val n=reader.read(chunk);if(n<0) break;require(out.length+n<=8*1024*1024);out.append(chunk,0,n) };out.toString() } ?: error("No input")
        db.importCSV(CSV.parse(text));done()
    } } }
    Column(Modifier.verticalScroll(rememberScrollState()).padding(20.dp),verticalArrangement=Arrangement.spacedBy(16.dp)) {
        Text(stringResource(R.string.backup),style=MaterialTheme.typography.titleLarge);Text(stringResource(R.string.backup_help))
        OutlinedTextField(passphrase,{passphrase=it},label={Text(stringResource(R.string.passphrase))},visualTransformation=PasswordVisualTransformation(),keyboardOptions=KeyboardOptions(keyboardType=KeyboardType.Password),singleLine=true,modifier=Modifier.fillMaxWidth())
        Button(onClick={export.launch("Taima.taimabackup")},enabled=!busy){Text(stringResource(R.string.export_backup))}
        OutlinedButton(onClick={import.launch(arrayOf("*/*"))},enabled=!busy){Text(stringResource(R.string.import_backup))}
        HorizontalDivider();OutlinedButton(onClick={csvExport.launch("Taima.csv")},enabled=!busy){Text(stringResource(R.string.export_csv))}
        OutlinedButton(onClick={csvImport.launch(arrayOf("text/*","application/csv","application/octet-stream"))},enabled=!busy){Text(stringResource(R.string.import_csv))}
        HorizontalDivider();Text(stringResource(R.string.privacy),style=MaterialTheme.typography.titleLarge);Text(stringResource(R.string.privacy_help))
    }
    pending?.let { uri -> AlertDialog(onDismissRequest={pending=null},title={Text(stringResource(R.string.restore_title))},text={Text(stringResource(R.string.restore_help))},confirmButton={TextButton(onClick={val phrase=passphrase;pending=null;action {
        val backup=context.contentResolver.openInputStream(uri)?.use { Archive.read(it,phrase) } ?: error("No input")
        db.restoreBackup(backup);done()
    }}){Text(stringResource(R.string.restore))}},dismissButton={TextButton(onClick={pending=null}){Text(stringResource(R.string.cancel))}}) }
}
@Composable private fun Party() {
    val context=LocalContext.current;val language=LocalConfiguration.current.locales[0].language
    val cards=remember { context.assets.open("party-content.json").bufferedReader().use { Records.parse(it.readText()).getAsJsonArray("deck").map(JsonElement::getAsJsonObject) } }
    var players by rememberSaveable { mutableStateOf("") };var intense by rememberSaveable { mutableStateOf(false) };var current by remember { mutableStateOf<JsonObject?>(null) };val seen=remember { mutableSetOf<String>() }
    val names=players.split(',').map(String::trim).filter(String::isNotEmpty).distinct()
    fun text(raw:String):String { var output=raw;names.forEachIndexed { i,name -> output=output.replace("{p${i+1}}",name).replace("{player${i+1}}",name) };return output.replace("{player}",names.firstOrNull() ?: "").replace("{other}",names.getOrNull(1) ?: "") }
    Column(Modifier.verticalScroll(rememberScrollState()).padding(20.dp),verticalArrangement=Arrangement.spacedBy(16.dp)) {
        Text(stringResource(R.string.play_help));Field(R.string.players,players,{players=it;current=null;seen.clear()})
        Row { Checkbox(intense,{intense=it;current=null;seen.clear()});Text(stringResource(R.string.intense),modifier=Modifier.padding(top=12.dp)) }
        Button(onClick={
            val eligible=cards.filter { it["enabled"]?.asBoolean!=false && (it.number("minPlayers") ?: 2.0)<=names.size && (intense || it["intense"]?.asBoolean!=true) }
            var deck=eligible.filter { it.text("id") !in seen };if(deck.isEmpty()) { seen.clear();deck=eligible }
            current=deck.randomOrNull()?.also { seen.add(it.text("id")) }
        },enabled=names.size>=2) { Text(stringResource(R.string.next_card)) }
        if(names.size<2) Text(stringResource(R.string.no_cards))
        current?.let { card ->
            HorizontalDivider();Text(text(card.text(if(language=="nl") "nl" else "en")),style=MaterialTheme.typography.headlineMedium)
        }
    }
}
