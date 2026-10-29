package nl.taima

import android.content.SharedPreferences
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.semantics.*
import androidx.compose.ui.res.*
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import com.google.gson.*
import kotlinx.coroutines.*
import java.time.*

@Composable internal fun T(key: String) { Text(LocalContext.current.coreText(key)) }
@Composable internal fun Page(content: @Composable ColumnScope.()->Unit) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement=Arrangement.spacedBy(16.dp), content=content)
}
@Composable internal fun MoreMenu(select: (String)->Unit) {
    LazyColumn(contentPadding=PaddingValues(12.dp)) {
        items(listOf("scan" to R.string.scan,"play" to R.string.play,"tools" to R.string.tools,"wellbeing" to R.string.wellbeing,"history" to R.string.history,"milestones" to R.string.milestones,"year" to R.string.year_review,"settings" to R.string.settings,"whatsnew" to R.string.whats_new)) { (key,title) ->
            ListItem(headlineContent={Text(stringResource(title))},modifier=Modifier.clickable { select(key) }.heightIn(min=64.dp));HorizontalDivider()
        }
    }
}

@Composable internal fun Dashboard(bags: List<JsonObject>, section: String="stats",openBag:(String)->Unit={}) {
    var year by rememberSaveable { mutableIntStateOf(Year.now().value) }
    var month by rememberSaveable { mutableStateOf(YearMonth.now().toString()) }
    var data by remember { mutableStateOf<JsonObject?>(null) };var failed by remember { mutableStateOf(false) }
    var selectedDay by rememberSaveable(month) {mutableStateOf<String?>(null)}
    val largeText=LocalConfiguration.current.fontScale>1.5f
    val context=LocalContext.current
    LaunchedEffect(bags,year,month) { failed=false;data=null
        try { data=withContext(Dispatchers.Default) { Domain.call("dashboard","bags" to bags,"year" to year,"month" to YearMonth.parse(month).atDay(1).atStartOfDay(ZoneId.systemDefault()).toInstant().toString()).asJsonObject } }
        catch(e: CancellationException) {throw e} catch(_:Exception) {failed=true}
    }
    Page {
        if(failed) Text(stringResource(R.string.operation_failed))
        val d=data
        if(d==null && !failed) CircularProgressIndicator()
        if(d!=null) when(section) {
            "milestones" -> d.array("milestones").forEach { item -> val m=item.asJsonObject
                Text(context.coreText(m.text("title")),style=MaterialTheme.typography.titleLarge)
                Text(context.coreText(m.text("detail")));Text("${m.number("current")?.toInt()} / ${m.number("target")?.toInt()}",fontFamily=FontFamily.Monospace)
                LinearProgressIndicator(progress={ ((m.number("current") ?: 0.0)/(m.number("target") ?: 1.0)).toFloat().coerceIn(0f,1f) },modifier=Modifier.fillMaxWidth())
                Text(context.coreText(m.text("hint")));HorizontalDivider()
            }
            "history" -> {
                Text(month,style=MaterialTheme.typography.headlineSmall)
                FlowRow(horizontalArrangement=Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(enabled=d.array("historyMonths").firstOrNull()?.asString?.let {YearMonth.from(Instant.parse(it).atZone(ZoneId.systemDefault()))<YearMonth.parse(month)}==true,onClick={month=YearMonth.parse(month).minusMonths(1).toString()}) { Text(stringResource(R.string.previous_month)) }
                    OutlinedButton(enabled=YearMonth.parse(month)<YearMonth.now(),onClick={month=YearMonth.parse(month).plusMonths(1).toString()}) { Text(stringResource(R.string.next_month)) }
                }
                Text(stringResource(R.string.calendar_summary,d.number("daysWithUse")!!.toInt(),d.number("daysWithoutUse")!!.toInt()))
                val days=d.array("history").map {it.asJsonObject}
                fun describe(day:JsonObject):String {
                    val label=date(day.text("date"));val sessions=day.number("sessions")!!.toInt()
                    return if(sessions>0) context.getString(R.string.day_sessions,label,number(day.number("grams")),sessions)
                        else context.getString(if(day["tracked"].asBoolean) R.string.day_no_use else R.string.day_untracked,label)
                }
                if(largeText) days.forEach {day ->
                    TextButton(onClick={selectedDay=day.text("date")}) {Text(describe(day))}
                } else {
                    val first=YearMonth.parse(month).atDay(1)
                    val weekStart=java.time.temporal.WeekFields.of(java.util.Locale.getDefault()).firstDayOfWeek.value
                    Row(Modifier.fillMaxWidth()) {repeat(7) {offset ->
                        val day=DayOfWeek.of((weekStart-1+offset)%7+1)
                        Text(day.getDisplayName(java.time.format.TextStyle.NARROW,java.util.Locale.getDefault()),Modifier.weight(1f).clearAndSetSemantics {})
                    }}
                    val blanks=(first.dayOfWeek.value-weekStart+7)%7
                    val cells=List<JsonObject?>(blanks) {null}+days
                    cells.chunked(7).forEach {week ->Row(Modifier.fillMaxWidth()) {
                        week.forEach {day ->Box(Modifier.weight(1f)) {if(day!=null) {
                            val sessions=day.number("sessions")!!.toInt()
                            TextButton(onClick={selectedDay=day.text("date")},modifier=Modifier.heightIn(min=48.dp).semantics {contentDescription=describe(day);selected=selectedDay==day.text("date")},colors=ButtonDefaults.textButtonColors(containerColor=if(sessions>0) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surface)) {
                                Text(Instant.parse(day.text("date")).atZone(ZoneId.systemDefault()).dayOfMonth.toString())
                            }
                        }}}
                        repeat(7-week.size) {Spacer(Modifier.weight(1f))}
                    }}
                }
                selectedDay?.let {selected ->days.firstOrNull {it.text("date")==selected}?.let {Text(describe(it))}
                    val local=Instant.parse(selected).atZone(ZoneId.systemDefault()).toLocalDate()
                    bags.forEach {bag ->bag.array("usageLog").filter {Instant.parse(it.asJsonObject.text("date")).atZone(ZoneId.systemDefault()).toLocalDate()==local}.forEach {entry ->
                        TextButton(onClick={openBag(bag.text("id"))}) {Text("${bag.text("name")} · ${amountLabel(bag,entry.asJsonObject.number("grams"))}")}
                    }}
                }
                T("On this day");d.array("memories").forEach {item ->val m=item.asJsonObject
                    TextButton(onClick={openBag(m.text("id"))}) {Text("${m.text("name")} · ${m.number("years")?.toInt()}")}
                }
            }
            "year" -> {
                FlowRow(horizontalArrangement=Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(onClick={year--}) { Text((year-1).toString()) };Text(year.toString(),style=MaterialTheme.typography.headlineSmall)
                    OutlinedButton(onClick={year++}) { Text((year+1).toString()) }
                }
                val y=d.getAsJsonObject("year")
                Metric(R.string.collection,y.number("count")?.toInt().toString());Metric(R.string.total_weight,"${number(y.number("grams"))} g")
                Metric(R.string.strains,y.number("strains")?.toInt().toString());Metric(R.string.growers,y.number("growers")?.toInt().toString())
                Text(y.text("favourite"));Text(y.text("topGrower"))
                Button(onClick={ShareCards.share(context,y)}) { Text(stringResource(R.string.share_card)) }
            }
            else -> {
                Text(pluralStringResource(R.plurals.item_count,d.number("count")!!.toInt(),d.number("count")!!.toInt()),style=MaterialTheme.typography.headlineMedium)
                listOf("grams" to R.string.total_weight,"stash" to R.string.stash_weight,"averageTHC" to R.string.average_thc,"averageHashTHC" to R.string.hash_thc,"averageScore" to R.string.score,"strains" to R.string.strains,"growers" to R.string.growers,"spent" to R.string.spent,"pricePerGram" to R.string.per_gram,"sessions" to R.string.sessions,"usedToday" to R.string.used_today,"usedWeek" to R.string.used_week,"daysSupply" to R.string.days_supply,"freeDays" to R.string.free_days).forEach { (key,label) -> Metric(label,number(d.number(key))) }
                HorizontalDivider()
                d.array("formCounts").forEach { f -> val row=f.asJsonObject;val count=row.number("count")!!.toInt();val resource=when(row.text("form")) {"bag"->R.plurals.bag_count;"jar"->R.plurals.jar_count;"preroll"->R.plurals.preroll_count;"rosin"->R.plurals.rosin_count;"edible"->R.plurals.edible_count;else->R.plurals.hash_count};Text(pluralStringResource(resource,count,count)) }
                Text(stringResource(R.string.monthly_collection),style=MaterialTheme.typography.titleLarge)
                Bars(d.array("months").map {it.asJsonObject.let {v -> date(v.text("date")) to (v.number("count") ?: 0.0)}})
                Text(stringResource(R.string.thc_spread),style=MaterialTheme.typography.titleLarge)
                Bars(d.array("thcBins").map {it.asJsonObject.let {v -> "${v.number("lower")!!.toInt()}–${v.number("lower")!!.toInt()+1}%" to (v.number("count") ?: 0.0)}})
                listOf("producers" to R.string.growers,"methods" to R.string.method,"positive" to R.string.effects,"negative" to R.string.downsides,"flavors" to R.string.flavors,"topStrains" to R.string.top_strains,"moodByStrain" to R.string.mood_patterns,"moodByMethod" to R.string.mood_patterns).forEach { (key,title) ->
                    Text(stringResource(title),style=MaterialTheme.typography.titleLarge)
                    d.array(key).forEach {row ->val v=row.asJsonObject;Text(context.coreText(v.text("name")));Text(listOfNotNull(v.number("count")?.let(::number),v.number("score")?.let(::number),v.number("change")?.let(::number)).joinToString(" · "))}
                }
                Text(stringResource(R.string.patterns_help))
                Text(stringResource(R.string.shops),style=MaterialTheme.typography.titleLarge)
                d.array("shops").forEach { s -> val v=s.asJsonObject;Text(v.text("name"));Metric(R.string.spent,"€ ${number(v.number("euros"))}");Metric(R.string.per_gram,"€ ${number(v.number("perGram"))}") }
            }
        }
    }
}

@Composable internal fun Library(db: BagDatabase,bags: List<JsonObject>,action: (()->Unit)->Unit) {
    var query by rememberSaveable { mutableStateOf("") };var name by rememberSaveable { mutableStateOf("") }
    var wishesOnly by rememberSaveable { mutableStateOf(false) };var wishes by remember { mutableStateOf<List<JsonElement>>(emptyList()) }
    var data by remember { mutableStateOf<JsonObject?>(null) };var failed by remember { mutableStateOf(false) };var revision by remember { mutableIntStateOf(0) }
    val context=LocalContext.current
    LaunchedEffect(query,name,bags,revision) {
        data=null;delay(200);failed=false
        try { val result=withContext(Dispatchers.Default) { Domain.core.catalog(query,name,bags) to db.snapshot().array("wishlist") };data=result.first;wishes=result.second }
        catch(e:CancellationException) {throw e} catch(_:Exception) {failed=true}
    }
    Column {
        OutlinedTextField(query,{query=it;name=""},label={Text(stringResource(R.string.search_library))},modifier=Modifier.fillMaxWidth().padding(16.dp))
        if(failed) Text(stringResource(R.string.operation_failed),Modifier.padding(16.dp))
        if(name.isNotEmpty()) {
            TextButton(onClick={name=""}) { Text(stringResource(R.string.back)) }
            val strain=data?.getAsJsonObject("strain")
            if(strain==null && data!=null) Text(stringResource(R.string.no_lineage),Modifier.padding(16.dp))
            if(strain!=null) Page {
                Text(strain.text("name"),style=MaterialTheme.typography.headlineMedium)
                Text(strain.array("aliases").joinToString { it.asString });Text(strain.text("breeder"))
                val wished=wishes.any { it.asJsonObject.text("key")==strain.text("id") }
                OutlinedButton(onClick={action { db.toggleWish(strain.text("id"),strain.text("name"));revision++ }}) { Text(stringResource(if(wished) R.string.remove_wish else R.string.add_wish)) }
                if(strain["reported"].asBoolean) Text(stringResource(R.string.reported_lineage))
                Text(stringResource(R.string.family_tree),style=MaterialTheme.typography.titleLarge)
                data?.let {FamilyTree(it) {selected ->name=selected;data=null}}
                Text(stringResource(R.string.sources),style=MaterialTheme.typography.titleLarge)
                CatalogSources(strain.array("sources").map {it.asString})
                listOf("effects","downsides","flavors").forEach { field -> Text(strain.array(field).joinToString { context.coreText(it.asString) }) }
                Text(stringResource(R.string.your_bags));data?.array("owned")?.forEach { Text(it.asJsonObject.text("name")) }
                Text(stringResource(R.string.library_caution))
            }
        } else {
            FilterChip(selected=wishesOnly,onClick={wishesOnly=!wishesOnly},label={Text(stringResource(R.string.wishlist))},modifier=Modifier.padding(horizontal=16.dp))
            val results=if(wishesOnly) wishes else data?.array("results").orEmpty()
            LazyColumn { items(results) { item -> val s=item.asJsonObject;ListItem(headlineContent={Text(s.text("name"))},supportingContent={Text(s.array("parents").joinToString(" × ") { it.asString })},modifier=Modifier.clickable { name=s.text("name") }.heightIn(min=64.dp));HorizontalDivider() } }
        }
    }
}

@Composable internal fun Games(bags: List<JsonObject>,prefs: SharedPreferences) {
    var result by remember { mutableStateOf<JsonObject?>(null) };var names by rememberSaveable { mutableStateOf(prefs.getString("party.names","").orEmpty()) }
    var busy by remember { mutableStateOf(false) };var error by remember { mutableStateOf(false) };var secret by rememberSaveable { mutableStateOf(false) }
    var gameID by rememberSaveable {mutableStateOf<String?>(null)}
    var missionSecret by remember {mutableStateOf(false)}
    var configure by rememberSaveable { mutableStateOf(false) };var timer by remember { mutableIntStateOf(0) };var ticking by remember { mutableStateOf(false) }
    val scope=rememberCoroutineScope();val context=LocalContext.current
    fun submit(action: String, vararg fields: Pair<String,Any?>) {
        if(busy) return;busy=true;error=false
        scope.launch { try {
            val next=withContext(Dispatchers.Default) {
                val settings=result?.getAsJsonObject("settings") ?: prefs.getString("party.settings",null)?.let { JsonParser.parseString(it).asJsonObject }
                val state=result?.getAsJsonObject("state") ?: prefs.getString("party.state",null)?.let { JsonParser.parseString(it).asJsonObject }
                Domain.call("party", "action" to action,"settings" to settings,"state" to state,"bags" to bags,*fields).asJsonObject.also {
                    prefs.edit().putString("party.settings",it["settings"].toString()).putString("party.state",it["state"].toString()).apply()
                }
            }
            if(action=="score" || action=="load") result?.let {previous ->listOf("card","roulette").forEach {key ->if(previous.has(key)) next.add(key,previous[key])}}
            result=next
            if(action!="score" && action!="load") {secret=false;missionSecret=false;timer=0;ticking=false}
        } catch(e:CancellationException) {throw e} catch(_:Exception) {error=true} finally {busy=false} }
    }
    LaunchedEffect(Unit) { submit("load") }
    LaunchedEffect(ticking,timer) { if(ticking && timer>0) { delay(1000);timer--;if(timer==0) ticking=false } }
    Page {
        Text(stringResource(R.string.play_help));if(error) Text(stringResource(R.string.operation_failed))
        if(busy) LinearProgressIndicator(Modifier.fillMaxWidth())
        OutlinedTextField(names,{names=it},label={Text(stringResource(R.string.players))},modifier=Modifier.fillMaxWidth())
        OutlinedButton(onClick={prefs.edit().putString("party.names",names).apply();submit("players","names" to names.split(",").map(String::trim))},enabled=!busy) { Text(stringResource(R.string.save_players)) }
        OutlinedButton(onClick={configure=!configure}) { Text(stringResource(R.string.customize)) }
        val settings=result?.getAsJsonObject("settings")
        if(configure && settings!=null) {
            PartyCustomization(settings,save={submit("load","settings" to it)},reset={submit(it)})
            listOf("onlyStash" to R.string.only_stash,"rouletteStrainSetting" to R.string.roulette_strain,"rouletteWaySetting" to R.string.roulette_way,"rouletteGameSetting" to R.string.roulette_game).forEach { (key,label) ->
                val on=settings[key]?.takeUnless { it.isJsonNull }?.asBoolean ?: true
                Row { Checkbox(on,{checked -> settings.addProperty(key,checked);submit("load") });Text(stringResource(label),Modifier.padding(top=12.dp)) }
            }
            result?.array("games")?.forEach {row ->val game=row.asJsonObject
                TextButton(onClick={gameID=game.text("id");configure=false}) {Text(game.text("title"))}
            }
            TextButton(onClick={gameID=null;configure=false}) {Text(stringResource(R.string.mixed_deck))}
            listOf("challenge","duel","vote","everyone","question","dilemma","herd","scale","bomb","quickfire","act","debate","mission","rule","minigame","smoke").forEach {kind ->
                val off=settings.array("deckKindsOff").map {it.asString}.toMutableSet()
                Row {Checkbox(kind !in off,{on ->if(on) off.remove(kind) else off.add(kind);settings.add("deckKindsOff",com.google.gson.Gson().toJsonTree(off));submit("load")});Text(context.coreText(kindTitle(kind)),Modifier.padding(top=12.dp))}
            }
            settings.array("ways").forEach { way -> val w=way.asJsonObject
                Row { Checkbox(w["enabled"].asBoolean,{checked ->w.addProperty("enabled",checked);submit("load")});Text(context.coreText(w.text("name")),Modifier.padding(top=12.dp)) }
            }
        }
        FlowRow(horizontalArrangement=Arrangement.spacedBy(8.dp)) {
            Button(onClick={submit("next","gameID" to gameID)},enabled=!busy) { Text(stringResource(R.string.next_card)) }
            OutlinedButton(onClick={submit("roulette")},enabled=!busy) { Text(stringResource(R.string.spin)) }
        }
        result?.getAsJsonObject("roulette")?.let { spin ->
            Text(spin.text("playerName"));Text(spin.getAsJsonObject("way")?.text("name")?.let(context::coreText).orEmpty())
            Text(bags.find { it.text("id")==spin.text("bagID") }?.text("name").orEmpty())
        }
        result?.getAsJsonObject("card")?.let { card ->
            val kind=card.text("kind")
            Text(context.coreText(kindTitle(kind)),style=MaterialTheme.typography.titleLarge)
            Text(when(kind) {
                "herd" -> stringResource(R.string.herd_prompt,card.text("prompt"))
                "scale" -> stringResource(R.string.scale_prompt,card.array("names").firstOrNull()?.asString.orEmpty())
                "missionEnd" -> stringResource(R.string.mission_end_prompt,card.array("names").firstOrNull()?.asString.orEmpty())
                else -> card.text("text")
            },style=MaterialTheme.typography.headlineSmall)
            if(card.array("scaleEnds").isNotEmpty()) Text(card.array("scaleEnds").joinToString(" — ") { it.asString })
            if(card.has("secret") || card.has("target")) {
                OutlinedButton(onClick={secret=!secret}) { Text(stringResource(if(secret) R.string.hide_secret else R.string.reveal_secret)) }
                if(secret) Text(card.text("secret").ifEmpty {card.text("target")})
            }
            card.getAsJsonObject("game")?.let { game ->
                Text(context.coreText(game.text("hook")));Text(context.coreText(game.text("detail")));Text(context.coreText(game.text("puff")))
            }
            card.getAsJsonObject("spin")?.let {spin ->
                Text((spin.array("prompts").map {it.asString}+spin.text("letter")+spin.text("category")).filter(String::isNotBlank).joinToString("\n"))
                spin.array("combo").forEach {way ->Text(context.coreText(way.asJsonObject.text("name")))}
            }
            if(card.has("seconds") || card.has("fuse")) {
                Button(onClick={timer=(card.number("seconds") ?: card.number("fuse") ?: 30.0).toInt();ticking=true}) { Text(stringResource(R.string.start_timer)) }
                if(kind!="bomb" || !ticking) Text(timer.toString(),style=MaterialTheme.typography.headlineMedium,fontFamily=FontFamily.Monospace)
                else Text(stringResource(R.string.pass_phone))
            }
        }
        result?.getAsJsonObject("state")?.getAsJsonObject("rule")?.let {rule ->
            Text(stringResource(R.string.active_rule),style=MaterialTheme.typography.titleLarge)
            Text(rule.text("text"));Text(rule.text("end"))
            Text(stringResource(R.string.cards_left,rule.number("cardsLeft")?.toInt() ?: 0))
        }
        result?.getAsJsonObject("state")?.getAsJsonObject("mission")?.let {mission ->
            Text(stringResource(R.string.active_mission,mission.text("name")))
            TextButton(onClick={missionSecret=!missionSecret}) {Text(stringResource(if(missionSecret) R.string.hide_secret else R.string.reveal_secret))}
            if(missionSecret) Text(mission.text("mission"))
        }
        Text(stringResource(R.string.standings),style=MaterialTheme.typography.titleLarge)
        result?.array("standings")?.forEach { row -> val p=row.asJsonObject
            Text("${p.text("name")} · ${p.number("points")?.toInt()} · ${p.number("sjaak")?.toInt()}")
            FlowRow(horizontalArrangement=Arrangement.spacedBy(8.dp)) {
                OutlinedButton(onClick={submit("score","id" to p.text("id"),"points" to 1)}) { Text(stringResource(R.string.point)) }
                OutlinedButton(onClick={submit("score","id" to p.text("id"),"sjaak" to 1)}) { Text(stringResource(R.string.sjaak)) }
                OutlinedButton(onClick={submit("score","id" to p.text("id"),"legendary" to 1)}) { Text(stringResource(R.string.legendary)) }
            }
        }
    }
}
private fun kindTitle(kind:String) = mapOf("herd" to "Same brain","scale" to "On a scale","bomb" to "Hot potato","mission" to "Secret mission","missionEnd" to "Mission over","standings" to "Standings","legendary" to "Legendary","challenge" to "Challenge","duel" to "Duel","vote" to "Vote","everyone" to "Everyone","question" to "Question","dilemma" to "Dilemma","quickfire" to "Quickfire","act" to "Act it out","debate" to "Debate","rule" to "Table rule","ruleEnd" to "Rule over","minigame" to "Mini-game","smoke" to "Smoke")[kind] ?: kind

@Composable internal fun ToolsScreen(prefs: SharedPreferences) {
    var grams by rememberSaveable { mutableStateOf("1") };var thc by rememberSaveable { mutableStateOf("20") }
    var per by rememberSaveable { mutableStateOf(if(java.util.Locale.getDefault().language=="nl") "0,25" else "0.25") }
    var portions by rememberSaveable { mutableStateOf("10") };var efficiency by rememberSaveable { mutableStateOf("70") }
    var data by remember { mutableStateOf<JsonObject?>(null) };var invalid by remember { mutableStateOf(false) }
    var waitStart by rememberSaveable { mutableLongStateOf(prefs.getLong("edible.start",0)) };var elapsed by remember { mutableLongStateOf(0) }
    LaunchedEffect(grams,thc,per,portions,efficiency) {
        delay(200)
        try {
            val next=withContext(Dispatchers.Default) {
                val values=listOf(grams,thc,per,portions,efficiency).map(Domain::amount)
                require(values.all {it!=null})
                Domain.call("tools","grams" to values[0],"thc" to values[1],"perJoint" to values[2],"portions" to values[3],"efficiency" to values[4]!!/100).asJsonObject
            }
            data=next;invalid=false
        } catch(e:CancellationException) {throw e} catch(_:Exception) {invalid=true;data=null}
    }

    LaunchedEffect(waitStart) { while(waitStart>0) { elapsed=(System.currentTimeMillis()-waitStart)/60000;delay(1000) } }
    Page {
        Field(R.string.grams,grams,{grams=it},true);Field(R.string.thc,thc,{thc=it},true);Field(R.string.per_joint,per,{per=it},true)
        Field(R.string.portions,portions,{portions=it},true);Field(R.string.efficiency,efficiency,{efficiency=it},true)
        if(invalid) Text(stringResource(R.string.invalid_fields))
        data?.let { d -> Metric(R.string.joints,number(d.number("joints")));Metric(R.string.thc_per_joint,number(d.number("thc")));Metric(R.string.thc_per_portion,number(d.number("portionMG"))) }
        Text(stringResource(R.string.estimate_help));HorizontalDivider()
        Text(stringResource(R.string.edible_timer),style=MaterialTheme.typography.titleLarge)
        Text(stringResource(R.string.wait_help))
        if(waitStart>0) Text(pluralStringResource(R.plurals.minutes_count,elapsed.toInt(),elapsed.toInt()))
        Button(onClick={waitStart=System.currentTimeMillis();prefs.edit().putLong("edible.start",waitStart).apply()}) { Text(stringResource(R.string.start_timer)) }
        if(waitStart>0) OutlinedButton(onClick={waitStart=0;prefs.edit().remove("edible.start").apply()}) { Text(stringResource(R.string.stop_timer)) }
        HorizontalDivider();Text(stringResource(R.string.safer_use),style=MaterialTheme.typography.titleLarge)
        Text(stringResource(R.string.safer_use_help));Text(stringResource(R.string.decarb_help));ToolGuides()
    }
}

@Composable internal fun Onboarding(prefs: SharedPreferences) {
    var show by rememberSaveable { mutableStateOf(prefs.getInt("onboarding.build",0)<BuildConfig.VERSION_CODE) }
    if(show) Welcome(prefs.getInt("onboarding.build",0)>0) { prefs.edit().putInt("onboarding.build",BuildConfig.VERSION_CODE).apply();show=false }
}
@Composable internal fun Welcome(update: Boolean,done: ()->Unit) {
    androidx.compose.ui.window.Dialog(onDismissRequest=done,properties=androidx.compose.ui.window.DialogProperties(usePlatformDefaultWidth=false)) {
        Surface(Modifier.fillMaxSize()) { Page {
            Text(stringResource(if(update) R.string.whats_new else R.string.welcome),style=MaterialTheme.typography.headlineLarge)
            if(update) {
                val context=LocalContext.current
                val releases=remember {context.assets.open("release-highlights.json").reader().use {JsonParser.parseReader(it).asJsonArray.toList()}}
                Text(stringResource(R.string.iphone_release_history))
                releases.forEach {entry ->val release=entry.asJsonObject
                    Text(stringResource(R.string.build_number,release.number("build")!!.toInt()),style=MaterialTheme.typography.titleLarge)
                    release.array("items").forEach {item ->val value=item.asJsonObject
                        Text(context.coreText(value.text("title")),style=MaterialTheme.typography.titleMedium)
                        Text(context.coreText(value.text("detail")))
                    }
                }
            }
            Text(stringResource(R.string.onboarding_help));HorizontalDivider()
            Text(stringResource(R.string.onboarding_features));Text(stringResource(R.string.scan_review_help))
            Button(onClick=done,modifier=Modifier.fillMaxWidth()) { Text(stringResource(R.string.get_started)) }
        } }
    }
}

@Composable internal fun Bars(rows: List<Pair<String,Double>>) {
    val maximum=rows.maxOfOrNull {it.second}?.coerceAtLeast(1.0) ?: 1.0
    rows.forEach { (label,value) ->
        Column(Modifier.fillMaxWidth(),verticalArrangement=Arrangement.spacedBy(4.dp)) {
            Text("$label · ${number(value)}")
            LinearProgressIndicator(progress={(value/maximum).toFloat().coerceIn(0f,1f)},modifier=Modifier.fillMaxWidth())
        }
    }
}
