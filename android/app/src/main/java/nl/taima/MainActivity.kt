package nl.taima

import android.os.Bundle
import androidx.glance.appwidget.updateAll
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

import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale

class MainActivity : ComponentActivity() {
    private var unlocked by mutableStateOf(false)
    private var route by mutableStateOf<String?>(null)
    override fun onNewIntent(intent:android.content.Intent) {super.onNewIntent(intent);setIntent(intent);route=intent.action}
    private var authenticating=false
    private val unlock=registerForActivityResult(ActivityResultContracts.StartActivityForResult()) {result ->
        authenticating=false;unlocked=result.resultCode==RESULT_OK
    }
    private fun authenticate() {
        if(authenticating) return
        val manager=getSystemService(android.app.KeyguardManager::class.java)
        if(!manager.isDeviceSecure) {unlocked=true;return}
        val intent=manager.createConfirmDeviceCredentialIntent(getString(R.string.app_name),getString(R.string.unlock_taima))
        if(intent!=null) {authenticating=true;unlock.launch(intent)}
    }
    override fun onCreate(savedInstanceState: Bundle?) {super.onCreate(savedInstanceState);route=intent?.action;enableEdgeToEdge();setContent {TaimaTheme {
        if(unlocked) Taima(route) {route=null} else Page { Text(stringResource(R.string.locked));Button(onClick={authenticate()}) {Text(stringResource(R.string.unlock_taima))} }
    }}}
    override fun onStart() {super.onStart();if(getSharedPreferences("taima",0).getBoolean("privacy.lock",false)) {
        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE)
        if(!unlocked) authenticate()
    } else {unlocked=true;window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE)}}
    override fun onStop() {if(getSharedPreferences("taima",0).getBoolean("privacy.lock",false)) unlocked=false;super.onStop()}
}
@Composable internal fun TaimaTheme(content: @Composable () -> Unit) {
    val scheme = if (isSystemInDarkTheme()) darkColorScheme(primary=Color(0xFF85D5A4),onPrimary=Color(0xFF00391B),surface=Color(0xFF141714),surfaceContainer=Color(0xFF202420),secondary=Color(0xFFBBC5BB),onSecondaryContainer=Color(0xFFE3E8E1),secondaryContainer=Color(0xFF303630))
    else lightColorScheme(primary=Color(0xFF1B7A47),onPrimary=Color.White,surface=Color(0xFFF8FAF6),surfaceContainer=Color(0xFFEEF1EB),secondary=Color(0xFF516151),onSecondaryContainer=Color(0xFF182018),secondaryContainer=Color(0xFFE2E8DE))
    MaterialTheme(colorScheme=scheme,content=content)
}
private val destinations = listOf(R.string.collection, R.string.stash, R.string.stats, R.string.library, R.string.more)
private val icons = listOf(Icons.Default.Inventory2, Icons.Default.Grass, Icons.Default.BarChart, Icons.Default.MenuBook, Icons.Default.MoreHoriz)
@OptIn(ExperimentalMaterial3Api::class)
@Composable internal fun Taima(route:String?=null,consumeRoute:()->Unit={}) {
    val context = LocalContext.current
    val db = remember { BagDatabase(context) }
    DisposableEffect(db) { onDispose { db.close() } }
    val prefs = remember { context.getSharedPreferences("taima",0) }
    var inUse by rememberSaveable { mutableStateOf(prefs.getString("inUse",null)) }
    var ready by remember { mutableStateOf(false) }
    var more by rememberSaveable { mutableStateOf("menu") }
    var bags by remember { mutableStateOf<List<JsonObject>>(emptyList()) }
    var page by rememberSaveable { mutableIntStateOf(0) }
    var detail by rememberSaveable { mutableStateOf<String?>(null) }
    var editing by remember { mutableStateOf<JsonObject?>(null) }
    var importQueue by remember {mutableStateOf<List<JsonObject>>(emptyList())}
    var labelSample by remember {mutableStateOf<String?>(null)}
    var editConflict by remember {mutableStateOf(false)}
    var logging by remember { mutableStateOf<JsonObject?>(null) }
    var busy by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope(); val mutex = remember { Mutex() }; val snackbar = remember { SnackbarHostState() }
    val failed = stringResource(R.string.operation_failed); val done = stringResource(R.string.done)
    fun action(block: () -> Unit) { if(busy) return; busy=true; scope.launch {
        try { val next = withContext(Dispatchers.IO) { mutex.withLock { block(); db.all() } }; withContext(Dispatchers.IO) {Reminders.check(context,bags,next)}; bags=next; StashWidget().updateAll(context);withContext(Dispatchers.IO) {StashNotification.update(context)} }
        catch (e: Exception) {
            if(e is ConcurrentEdit) {
                editConflict=true
                bags=withContext(Dispatchers.IO) {mutex.withLock {db.all()}}
            }
            snackbar.showSnackbar(failed)
        }
        finally { busy=false }
    } }
    LaunchedEffect(Unit) { action { Domain.core = Core(context); ready=true } }
    androidx.lifecycle.compose.LifecycleEventEffect(androidx.lifecycle.Lifecycle.Event.ON_RESUME) {
        if(ready) action {}
    }
    LaunchedEffect(route,ready,busy) {if(ready && !busy && route!=null) {
        when(route) {
            "nl.taima.SCAN" -> {page=4;more="scan";detail=null}
            "nl.taima.STASH" -> {page=1;detail=null}
            "nl.taima.ADD" -> action {editing=Domain.call("bag.new").asJsonObject.apply {addProperty("stockState",prefs.getString("editor.defaultStock","empty"))}}
            "nl.taima.LOG" -> {page=1;detail=null;logging=bags.firstOrNull {it.text("id")==inUse}}
        }
        consumeRoute()
    }}
    val selected = bags.find { it.text("id") == detail }
    BackHandler(detail != null || editing != null || logging != null || more != "menu") { if(editing != null) {Photos.clearDraft(context,editing!!);editing=importQueue.firstOrNull();importQueue=importQueue.drop(1)} else if(logging != null) logging=null else if(detail != null) detail=null else more="menu" }
    val wide = LocalConfiguration.current.screenWidthDp >= 600
    Scaffold(
        topBar = { TopAppBar(title = { Text(if(editing != null) stringResource(R.string.edit_bag) else selected?.text("name") ?: stringResource(destinations[page]), maxLines=2) }, navigationIcon = { if(detail != null) IconButton(onClick={detail=null}) { Icon(Icons.AutoMirrored.Filled.ArrowBack,stringResource(R.string.back)) } }) },
        bottomBar = { if(!wide) NavigationBar { destinations.forEachIndexed { i, title -> NavigationBarItem(selected=page==i,onClick={page=i; detail=null},icon={Icon(icons[i],null)},label={Text(stringResource(title))}) } } },
        floatingActionButton = { if(ready && page==0 && detail==null) FloatingActionButton(onClick={action { editing=Domain.call("bag.new").asJsonObject.apply {addProperty("stockState",prefs.getString("editor.defaultStock","empty"))} }}) { Icon(Icons.Default.Add,stringResource(R.string.add_bag)) } },
        snackbarHost = { SnackbarHost(snackbar) }
    ) { padding ->
        Row(Modifier.fillMaxSize().padding(padding)) {
            if(wide) NavigationRail { destinations.forEachIndexed { i,title -> NavigationRailItem(selected=page==i,onClick={page=i;detail=null},icon={Icon(icons[i],null)},label={Text(stringResource(title))}) } }
            Column(Modifier.weight(1f)) {
                if(busy) LinearProgressIndicator(Modifier.fillMaxWidth())
                when {
                    !ready -> CircularProgressIndicator(Modifier.padding(24.dp))
                    selected != null -> BagDetail(selected, db, ::action, {detail=null}, onEdit={editing=selected.deepCopy()}, onUse={inUse=selected.text("id");prefs.edit().putString("inUse",inUse).apply();action { db.put(Domain.call("bag.open", "bag" to selected).asJsonObject) };detail=null;page=1}, onLog={logging=selected})
                    page == 0 -> Column {
                        BulkImport(!busy && editing==null) {drafts -> if(drafts.isNotEmpty()) {importQueue=drafts.drop(1);editing=drafts.first()} }
                        Box(Modifier.weight(1f)) {Collection(bags) {detail=it.text("id")}}
                    }
                    page == 1 -> {
                        val bag = bags.find { it.text("id")==inUse }
                        if(bag==null) EmptyState(R.string.no_stash,R.string.no_stash_help)
                        else Stash(bag, !busy, { amount -> action { db.mutate(bag.text("id")) {fresh -> Domain.call("bag.use", "bag" to fresh, "amount" to amount).asJsonObject} } }, { logging=bag },{detail=bag.text("id")})
                    }
                    page == 2 -> Dashboard(bags)
                    page == 3 -> Library(db, bags, ::action)
                    page == 4 -> when(more) {
                        "play" -> Games(bags, prefs)
                        "tools" -> ToolsScreen(prefs)
                        "wellbeing" -> WellbeingScreen(prefs, bags)
                        "milestones" -> Dashboard(bags, "milestones")
                        "history" -> Dashboard(bags, "history") {detail=it}
                        "year" -> Dashboard(bags, "year")
                        "settings" -> Settings(db, busy, ::action, onReset={inUse=null;page=0;more="menu";detail=null}) { scope.launch { snackbar.showSnackbar(done) } }
                        "scan" -> Scanner { draft -> editing=draft }
                        "whatsnew" -> Welcome(true) { more="menu" }
                        else -> MoreMenu { more=it }
                    }
                }
            }
        }
    }
    if(ready) Onboarding(prefs)
    LaunchedEffect(editing?.text("id")) {editConflict=false}
    editing?.let { bag ->
        val existed=remember(bag) {bags.any {it.text("id")==bag.text("id")}}
        Editor(bag, conflict=editConflict, onDismiss={Photos.clearDraft(context,bag);editing=importQueue.firstOrNull();importQueue=importQueue.drop(1)}) { edited -> action { db.transaction {db.verifyEditBaseline(bag,existed); db.put(Domain.call("bag.save", "bag" to Photos.attach(context,db,edited)).asJsonObject);db.rememberProducer(edited) }; LabelLearning.learn(context,bag,edited)
        if(!existed && prefs.getBoolean("learning.share",false) && bag.has("androidReadName")) {
            labelSample=Domain.call("label.sample","original" to bag,"bag" to edited,"appVersion" to BuildConfig.VERSION_NAME).takeUnless {it.isJsonNull}?.asString
        }
        Photos.clearDraft(context,edited);editing=importQueue.firstOrNull();importQueue=importQueue.drop(1) } } }
    labelSample?.let {sample ->LabelSampleSheet(sample) {labelSample=null}}
    logging?.let { bag -> SessionEditor(bag,onDismiss={logging=null}) { details -> action {
        db.mutate(bag.text("id")) {fresh -> Domain.call("bag.use","bag" to fresh,*details.entrySet().map {it.key to it.value}.toTypedArray()).asJsonObject };logging=null
    } } }

}
@Composable internal fun EmptyState(title:Int, body:Int) { Column(Modifier.padding(24.dp),verticalArrangement=Arrangement.spacedBy(12.dp)) { Text(stringResource(title),style=MaterialTheme.typography.headlineSmall);Text(stringResource(body),color=MaterialTheme.colorScheme.onSurfaceVariant) } }
@Composable internal fun BagDetail(bag:JsonObject,db:BagDatabase,action:(()->Unit)->Unit,deleted:()->Unit,onEdit:()->Unit,onUse:()->Unit,onLog:()->Unit) {
    var sharing by remember {mutableStateOf(false)}
    if(sharing) ItemShareSheet(bag) {sharing=false}
    Column(Modifier.verticalScroll(rememberScrollState()).padding(20.dp),verticalArrangement=Arrangement.spacedBy(16.dp)) {
        PhotoGallery(bag)
        OutlinedButton(onClick={sharing=true}) {Text(stringResource(R.string.share_card))}
        Text(bag.text("producer"),style=MaterialTheme.typography.titleMedium)
        Metric(if(isEdible(bag)) R.string.pieces else R.string.grams,amountLabel(bag,bag.number("grams")))
        if(isEdible(bag)) Metric(R.string.thc_per_piece,number(bag.number("thcMilligrams")))
        else Metric(R.string.thc,bag.getAsJsonObject("thc")?.number("percent")?.let { "${number(it)}%" } ?: stringResource(R.string.unknown))
        Text(bag.text("notes"))
        Button(onClick=onUse,enabled=Domain.remaining(bag)>0) { Text(stringResource(R.string.use_bag)) }
        FlowRow(horizontalArrangement=Arrangement.spacedBy(12.dp)) { OutlinedButton(onClick=onEdit) { Text(stringResource(R.string.edit_bag)) }; OutlinedButton(onClick=onLog,enabled=Domain.remaining(bag)>0) { Text(stringResource(R.string.log_session)) } }
        Sessions(bag)
        BagExtras(bag,db,action,deleted)
    }
}
@Composable internal fun Stash(bag:JsonObject,enabled:Boolean,quick:(Double)->Unit,session:()->Unit,details:()->Unit) {
    Column(Modifier.verticalScroll(rememberScrollState()).padding(20.dp),verticalArrangement=Arrangement.spacedBy(16.dp)) {
        Text(stringResource(R.string.in_use),style=MaterialTheme.typography.titleMedium)
        Text(bag.text("name"),style=MaterialTheme.typography.headlineMedium)
        Metric(if(isEdible(bag)) R.string.remaining_pieces else R.string.remaining,amountLabel(bag,Domain.remaining(bag)))
        FlowRow(horizontalArrangement=Arrangement.spacedBy(8.dp)) { (if(isEdible(bag)) listOf(0.5,1.0) else listOf(0.1,0.25,0.5)).forEach { amount -> OutlinedButton(onClick={quick(amount)},enabled=enabled && amount<=Domain.remaining(bag)) { Text(if(isEdible(bag)) stringResource(if(amount==0.5) R.string.ate_half else R.string.ate_one) else amountLabel(bag,amount)) } } }
        Domain.view(bag).number("unitGrams")?.let {unit ->
            OutlinedButton(onClick={quick(unit)},enabled=enabled && unit<=Domain.remaining(bag)) { Text(stringResource(R.string.log_preroll)) }
        }
        Button(onClick=session,enabled=enabled && Domain.remaining(bag)>0) { Text(stringResource(R.string.log_session)) }
        OutlinedButton(onClick=details) {Text(stringResource(R.string.item_details))}
        Sessions(bag)
    }
}
@Composable internal fun Sessions(bag:JsonObject) {
    Text(stringResource(R.string.session_log),style=MaterialTheme.typography.titleLarge)
    val sessions = bag.getAsJsonArray("usageLog")?.toList().orEmpty()
    if(sessions.isEmpty()) Text(stringResource(R.string.no_sessions))
    sessions.asReversed().forEach { element -> val entry=element.asJsonObject
        HorizontalDivider();Text("${amountLabel(bag,entry.number("grams"))} · ${date(entry.text("date"))}",style=MaterialTheme.typography.bodyLarge)
        Text("${stringResource(methodLabel(entry.text("method")))} ${entry.text("note")}",color=MaterialTheme.colorScheme.onSurfaceVariant)
    }
}
@Composable internal fun Metric(label:Int,value:String) { Column(Modifier.fillMaxWidth(),verticalArrangement=Arrangement.spacedBy(4.dp)) { Text(stringResource(label),style=MaterialTheme.typography.labelLarge);Text(value,style=MaterialTheme.typography.titleMedium,fontFamily=FontFamily.Monospace) } }
internal fun number(value:Double?):String = value?.let { java.text.NumberFormat.getNumberInstance().apply { maximumFractionDigits=2;isGroupingUsed=false }.format(it) } ?: "—"
internal fun date(value:String):String = runCatching { DateTimeFormatter.ofLocalizedDateTime(FormatStyle.SHORT).withZone(ZoneId.systemDefault()).format(Instant.parse(value)) }.getOrDefault(value)
internal fun methodLabel(method:String) = when(method) { "joint"->R.string.joint;"vape"->R.string.vape;"bong"->R.string.bong;"pipe"->R.string.pipe;"dab"->R.string.dab;"edible"->R.string.edible;else->R.string.other }
@OptIn(ExperimentalMaterial3Api::class)
@Composable internal fun Editor(original:JsonObject,conflict:Boolean=false,onDismiss:()->Unit,onSave:(JsonObject)->Unit) {
    val context=LocalContext.current;val scope=rememberCoroutineScope()
    val fields=remember(original) { mutableStateMapOf<String,String>().apply {putAll(editorValues(original))} }
    var draft by remember(original) { mutableStateOf(original.deepCopy()) };var error by remember {mutableStateOf(false)};var saving by remember {mutableStateOf(false)};var reading by remember {mutableStateOf(false)}
    var photoTarget by remember { mutableStateOf("androidDraftPhoto") }
    val photoPicker=rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->if(uri!=null) draft=draft.deepCopy().apply {addProperty(photoTarget,uri.toString())} }
    androidx.compose.ui.window.Dialog(onDismissRequest={if(!saving && !reading) {Photos.clearDraft(context,draft);onDismiss()}},properties=androidx.compose.ui.window.DialogProperties(usePlatformDefaultWidth=false)) {
        Surface(Modifier.fillMaxSize()) { Scaffold(topBar={TopAppBar(title={Text(stringResource(R.string.edit_bag))},navigationIcon={IconButton(onClick={Photos.clearDraft(context,draft);onDismiss()},enabled=!saving && !reading){Icon(Icons.AutoMirrored.Filled.ArrowBack,stringResource(R.string.cancel))}})},bottomBar={ Surface { Button(onClick={
            saving=true;scope.launch {try {
                val value=withContext(Dispatchers.Default) { Domain.call("bag.edit","bag" to draft,"fields" to fields.toMap()).asJsonObject }
                listOf("androidDraftPhoto","androidBackPhoto","androidFlowerPhoto").forEach {key ->if(draft.has(key)) value.add(key,draft[key])};onSave(value)
            } catch(e:CancellationException) {throw e} catch(_:Exception) {error=true} finally {saving=false} }
        },enabled=!saving && !reading && !conflict,modifier=Modifier.fillMaxWidth().padding(16.dp)) {Text(stringResource(R.string.save))} }}) { padding ->
            Column(Modifier.padding(padding).imePadding().verticalScroll(rememberScrollState()).padding(20.dp),verticalArrangement=Arrangement.spacedBy(12.dp)) {
                PhotoGallery(draft)
                PhotoChoices(draft) {draft=it}
                if(reading) LinearProgressIndicator(Modifier.fillMaxWidth())
                listOf("androidDraftPhoto" to R.string.front_photo,"androidBackPhoto" to R.string.back_photo,"androidFlowerPhoto" to R.string.flower_photo).forEach { (key,label) ->
                    OutlinedButton(enabled=!reading && !saving,onClick={photoTarget=key;photoPicker.launch(androidx.activity.result.PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))}) {Text(stringResource(label))}
                }
                OutlinedButton(enabled=!reading && !saving && (draft.text("androidBackPhoto").isNotBlank() || draft.text("backPhotoName").isNotBlank()),onClick={
                    val snapshot=fields.toMap();val photoSnapshot=draft.deepCopy()
                    reading=true;scope.launch {try {
                        val result=withContext(Dispatchers.IO) {
                            val uri=photoSnapshot.text("androidBackPhoto").takeIf(String::isNotBlank)?.let(android.net.Uri::parse)
                            val text=if(uri!=null) LabelOCR.read(context,uri) else BagDatabase(context).use {db -> LabelOCR.readBytes(context,db.photo(photoSnapshot.text("backPhotoName")) ?: error("Missing photo"))}
                            val current=Domain.call("bag.edit","bag" to photoSnapshot,"fields" to snapshot,"draft" to true).asJsonObject
                            Domain.call("label","bag" to current,"lines" to LabelOCR.lines(text),"back" to true).asJsonObject.getAsJsonObject("bag")
                        }
                        check(fields.toMap()==snapshot && draft==photoSnapshot)
                        fields.putAll(editorValues(result));draft=result.apply { listOf("androidDraftPhoto","androidBackPhoto","androidFlowerPhoto").forEach {key ->if(draft.has(key)) add(key,draft[key])} }
                    } catch(e:CancellationException) {throw e} catch(_:Exception) {error=true} finally {reading=false} }
                }) {Text(stringResource(R.string.read_back))}
                listOf("name" to R.string.name,"producer" to R.string.producer).forEach { (key,label)->Field(label,fields[key].orEmpty(),{fields[key]=it}) }
                Choice(R.string.form,fields["productForm"] ?: "bag",listOf("bag" to R.string.bag,"jar" to R.string.jar,"preroll" to R.string.preroll,"hash" to R.string.hash,"rosin" to R.string.rosin,"edible" to R.string.edibles)){fields["productForm"]=it}
                Choice(R.string.stock,fields["stockState"] ?: "empty",listOf("full" to R.string.full,"open" to R.string.open,"empty" to R.string.empty)){fields["stockState"]=it}
                Choice(R.string.strain_type,fields["strainType"].orEmpty(),listOf("" to R.string.unknown,"indica" to R.string.indica,"sativa" to R.string.sativa,"hybrid" to R.string.hybrid)){fields["strainType"]=it}
                val edible=fields["productForm"]=="edible"
                val amounts=if(edible) listOf("grams" to R.string.pieces,"remainingGrams" to R.string.remaining_pieces,"thcMilligrams" to R.string.thc_per_piece)
                    else listOf("grams" to R.string.grams,"remainingGrams" to R.string.remaining,"unitCount" to R.string.unit_count,"thc" to R.string.thc,"cbd" to R.string.cbd)
                (amounts+listOf("priceEuros" to R.string.price,"score" to R.string.score)).forEach { (key,label)->Field(label,fields[key].orEmpty(),{fields[key]=it},true) }
                if(!edible) listOf("thc","cbd").forEach {key ->
                    Text(stringResource(if(key=="thc") R.string.thc else R.string.cbd),style=MaterialTheme.typography.titleSmall)
                    Field(R.string.potency_lower,fields[key+"Lower"].orEmpty(),{fields[key+"Lower"]=it},true)
                    Row {Checkbox(fields[key+"Upper"]=="true",{fields[key+"Upper"]=it.toString()});Text(stringResource(R.string.upper_bound),Modifier.padding(top=12.dp))}
                    Choice(R.string.potency_basis,fields[key+"Basis"].orEmpty(),listOf("" to R.string.unknown,"thca" to R.string.thca,"totalTHC" to R.string.total_thc)){fields[key+"Basis"]=it}
                }
                listOf("shop" to R.string.shop,"shopCity" to R.string.town,"productID" to R.string.product_code,"sku" to R.string.sku,"ean" to R.string.ean,"collectedOn" to R.string.collected_on,"harvestedOn" to R.string.harvested,"packedOn" to R.string.packed,"bestBeforeOn" to R.string.best_before,"effects" to R.string.effects,"sideEffects" to R.string.downsides,"flavors" to R.string.flavors,"notes" to R.string.notes).forEach { (key,label)->Field(label,fields[key].orEmpty(),{fields[key]=it}) }
                Choice(R.string.buy_again,fields["wouldBuyAgain"].orEmpty(),listOf("" to R.string.unknown,"true" to R.string.yes,"false" to R.string.no)){fields["wouldBuyAgain"]=it}
                if(conflict) Text(stringResource(R.string.item_changed),color=MaterialTheme.colorScheme.error)
                if(error) Text(stringResource(R.string.invalid_fields),color=MaterialTheme.colorScheme.error)
            }
        } }
    }
}
@Composable internal fun Field(label:Int,value:String,change:(String)->Unit,numeric:Boolean=false) { OutlinedTextField(value,change,label={Text(stringResource(label))},singleLine=true,keyboardOptions=KeyboardOptions(keyboardType=if(numeric) KeyboardType.Decimal else KeyboardType.Text),modifier=Modifier.fillMaxWidth()) }
@Composable internal fun Choice(label:Int,value:String,options:List<Pair<String,Int>>,change:(String)->Unit) {
    var expanded by remember { mutableStateOf(false) }
    Column { Text(stringResource(label),style=MaterialTheme.typography.labelLarge)
        Box { OutlinedButton(onClick={expanded=true}) { Text(stringResource(options.firstOrNull { it.first==value }?.second ?: options.first().second)) }
            DropdownMenu(expanded,{expanded=false}) { options.forEach { (key,title) -> DropdownMenuItem(text={Text(stringResource(title))},onClick={change(key);expanded=false}) } }
        }
    }
}
@Composable internal fun Settings(db:BagDatabase,busy:Boolean,action:(()->Unit)->Unit,onReset:()->Unit,done:()->Unit) {
    val context=LocalContext.current
    var notifications by remember {mutableStateOf(context.getSharedPreferences("taima",0).getBoolean("stash.notification",false))}
    val permission=rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {granted ->notifications=granted;context.getSharedPreferences("taima",0).edit().putBoolean("stash.notification",granted).apply();action {}}
    var csvConfirm by remember {mutableStateOf(false)}
    var passphrase by remember { mutableStateOf("") }
    var pending by remember { mutableStateOf<android.net.Uri?>(null) }
    val folderPicker=rememberLauncherForActivityResult(ActivityResultContracts.OpenDocumentTree()) {uri -> if(uri!=null) {
        context.contentResolver.takePersistableUriPermission(uri,android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION or android.content.Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        val phrase=passphrase;action {AutomaticBackups.enable(context,uri,phrase);done()}
    } }
    val export=rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/octet-stream")) { uri -> uri?.let { val phrase=passphrase;action { context.contentResolver.openOutputStream(it)?.use { output -> BackupFiles.export(context, db, output, phrase) } ?: error("No output");done() } } }
    val import=rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { pending=it }
    val csvExport=rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/csv")) { uri -> uri?.let { action { context.contentResolver.openOutputStream(it)?.bufferedWriter()?.use { output -> output.write(Domain.call("csv.export", "bags" to db.all()).asString) } ?: error("No output");done() } } }
    val csvImport=rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri -> uri?.let { action {
        val text=context.contentResolver.openInputStream(it)?.bufferedReader()?.use { reader -> val out=StringBuilder();val chunk=CharArray(8192);while(true) { val n=reader.read(chunk);if(n<0) break;require(out.length+n<=8*1024*1024);out.append(chunk,0,n) };out.toString() } ?: error("No input")
        db.importCSV(Domain.call("csv.import", "text" to text).asJsonArray.map { it.asJsonObject });done()
    } } }
    Column(Modifier.verticalScroll(rememberScrollState()).padding(20.dp),verticalArrangement=Arrangement.spacedBy(16.dp)) {
        Text(stringResource(R.string.backup),style=MaterialTheme.typography.titleLarge);Text(stringResource(R.string.backup_help))
        OutlinedTextField(passphrase,{passphrase=it},label={Text(stringResource(R.string.passphrase))},visualTransformation=PasswordVisualTransformation(),keyboardOptions=KeyboardOptions(keyboardType=KeyboardType.Password),singleLine=true,modifier=Modifier.fillMaxWidth())
        Button(onClick={export.launch("Taima.taimabackup")},enabled=!busy){Text(stringResource(R.string.export_backup))}
        OutlinedButton(onClick={import.launch(arrayOf("*/*"))},enabled=!busy){Text(stringResource(R.string.import_backup))}
        OutlinedButton(onClick={folderPicker.launch(null)},enabled=!busy && passphrase.isNotBlank()) {Text(stringResource(R.string.enable_auto_backup))}
        OutlinedButton(onClick={action {AutomaticBackups.disable(context);done()}},enabled=!busy) {Text(stringResource(R.string.disable_auto_backup))}
        Text(stringResource(R.string.auto_backup_help))
        HorizontalDivider();OutlinedButton(onClick={csvConfirm=true},enabled=!busy){Text(stringResource(R.string.export_csv))}
        OutlinedButton(onClick={csvImport.launch(arrayOf("text/*","application/csv","application/octet-stream"))},enabled=!busy){Text(stringResource(R.string.import_csv))}
        HorizontalDivider()
        Text(stringResource(R.string.network_help))
        OutlinedButton(onClick={action {CatalogDownloads.update(context);done()}},enabled=!busy) {Text(stringResource(R.string.check_catalog))}
        val preferences=remember {context.getSharedPreferences("taima",0)}
        var appLock by remember {mutableStateOf(preferences.getBoolean("privacy.lock",false))}
        Row {Switch(appLock,{enabled ->
            if(!enabled || context.getSystemService(android.app.KeyguardManager::class.java).isDeviceSecure) {
                appLock=enabled;preferences.edit().putBoolean("privacy.lock",enabled).apply()
                (context as? android.app.Activity)?.window?.let {window ->if(enabled) window.addFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE) else window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE)}
            }
        });Text(stringResource(R.string.app_lock),Modifier.padding(12.dp))}
        var discreet by remember {mutableStateOf(preferences.getBoolean("discreet",false))}
        Row {Switch(discreet,{discreet=it;preferences.edit().putBoolean("discreet",it).apply();action {}});Text(stringResource(R.string.discreet),Modifier.padding(12.dp))}
        Row {
            Switch(notifications,{enabled ->
                if(enabled && android.os.Build.VERSION.SDK_INT>=33 && androidx.core.content.ContextCompat.checkSelfPermission(context,android.Manifest.permission.POST_NOTIFICATIONS)!=android.content.pm.PackageManager.PERMISSION_GRANTED) permission.launch(android.Manifest.permission.POST_NOTIFICATIONS)
                else {notifications=enabled;preferences.edit().putBoolean("stash.notification",enabled).apply();action {}}
            })
            Text(stringResource(R.string.stash_notification),Modifier.padding(12.dp))
        }
        HorizontalDivider();PreferenceSettings(db,busy,action,onReset)
        HorizontalDivider();Text(stringResource(R.string.privacy),style=MaterialTheme.typography.titleLarge);Text(stringResource(R.string.privacy_help));Licenses()
    }
    if(csvConfirm) AlertDialog(onDismissRequest={csvConfirm=false},title={Text(stringResource(R.string.export_csv))},text={Text(stringResource(R.string.csv_warning))},confirmButton={TextButton(onClick={csvConfirm=false;csvExport.launch("Taima.csv")}) {Text(stringResource(R.string.export_csv))}},dismissButton={TextButton(onClick={csvConfirm=false}) {Text(stringResource(R.string.cancel))}})
    pending?.let { uri -> AlertDialog(onDismissRequest={pending=null},title={Text(stringResource(R.string.restore_title))},text={Text(stringResource(R.string.restore_help))},confirmButton={TextButton(onClick={val phrase=passphrase;pending=null;action {
        context.contentResolver.openInputStream(uri)?.use { BackupFiles.restore(context,db,it,phrase) } ?: error("No input");done()
    }}){Text(stringResource(R.string.restore))}},dismissButton={TextButton(onClick={pending=null}){Text(stringResource(R.string.cancel))}}) }
}
