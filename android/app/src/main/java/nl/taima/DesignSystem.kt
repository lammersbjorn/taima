package nl.taima

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.google.gson.JsonObject
import kotlinx.coroutines.*

/** All roles are explicit: no dynamic colour and no inherited Material purple. */
@Composable internal fun TaimaTheme(content:@Composable ()->Unit) {
    val dark=isSystemInDarkTheme()
    val page=if(dark) Color.Black else Color(0xFFF2F2F4)
    val cell=if(dark) Color(0xFF1A1A1C) else Color.White
    val raised=if(dark) Color(0xFF2A2A2E) else Color(0xFFEAE9EE)
    val ink=if(dark) Color(0xFFF6F6F9) else Color(0xFF19191D)
    val secondary=if(dark) Color(0xFFB2B0B6) else Color(0xFF5E5D63)
    val edge=if(dark) Color(0xFF827F87) else Color(0xFF76737C)
    val green=Color(0xFF1B7A47)
    val error=if(dark) Color(0xFFFFB4AB) else Color(0xFFBA1A1A)
    val scheme=lightColorScheme(
        primary=green,onPrimary=Color.White,primaryContainer=raised,onPrimaryContainer=ink,inversePrimary=green,
        secondary=secondary,onSecondary=cell,secondaryContainer=raised,onSecondaryContainer=ink,
        tertiary=secondary,onTertiary=cell,tertiaryContainer=raised,onTertiaryContainer=ink,
        background=page,onBackground=ink,surface=cell,onSurface=ink,surfaceVariant=raised,onSurfaceVariant=secondary,
        surfaceTint=Color.Transparent,inverseSurface=ink,inverseOnSurface=cell,
        surfaceDim=page,surfaceBright=cell,surfaceContainerLowest=page,surfaceContainerLow=cell,
        surfaceContainer=cell,surfaceContainerHigh=raised,surfaceContainerHighest=raised,
        outline=edge,outlineVariant=raised,error=error,onError=if(dark) Color(0xFF690005) else Color.White,
        errorContainer=if(dark) Color(0xFF93000A) else Color(0xFFFFDAD6),onErrorContainer=if(dark) Color(0xFFFFDAD6) else Color(0xFF410002),scrim=Color.Black
    )
    val defaults=Typography()
    MaterialTheme(colorScheme=scheme,typography=Typography(
        headlineLarge=defaults.headlineLarge.copy(fontWeight=FontWeight.Bold),
        headlineMedium=defaults.headlineMedium.copy(fontWeight=FontWeight.Bold),
        headlineSmall=defaults.headlineSmall.copy(fontWeight=FontWeight.SemiBold),
        titleLarge=defaults.titleLarge.copy(fontWeight=FontWeight.SemiBold)
    ),shapes=Shapes(medium=RoundedCornerShape(16.dp),large=RoundedCornerShape(22.dp),extraLarge=RoundedCornerShape(28.dp)),content=content)
}

@Composable internal fun ContentCard(modifier:Modifier=Modifier,content:@Composable ColumnScope.()->Unit) {
    Surface(modifier.fillMaxWidth(),shape=RoundedCornerShape(22.dp),color=MaterialTheme.colorScheme.surface,tonalElevation=0.dp) {
        Column(Modifier.padding(20.dp),verticalArrangement=Arrangement.spacedBy(12.dp),content=content)
    }
}
@Composable internal fun Figure(value:String,label:String) {
    Column(Modifier.semantics(mergeDescendants=true) {},verticalArrangement=Arrangement.spacedBy(4.dp)) {
        Text(value,style=MaterialTheme.typography.headlineLarge.copy(fontFeatureSettings="tnum"))
        Text(label,style=MaterialTheme.typography.bodyMedium,color=MaterialTheme.colorScheme.onSurfaceVariant)
    }
}
@Composable internal fun ValueChip(value:String) {
    Surface(shape=RoundedCornerShape(50),color=MaterialTheme.colorScheme.surfaceContainerHigh) {
        Text(value,Modifier.padding(horizontal=10.dp,vertical=5.dp),style=MaterialTheme.typography.labelLarge.copy(fontFeatureSettings="tnum"))
    }
}
@Composable internal fun MetricTile(label:Int,value:String,icon:ImageVector,modifier:Modifier=Modifier) {
    ContentCard(modifier) {Icon(icon,null,tint=MaterialTheme.colorScheme.onSurfaceVariant);Figure(value,stringResource(label))}
}
/** Neutral chart marks leave green exclusively to controls and progress. Labels are
 * real Compose text; TalkBack gets every datum even when the chart is scrolled. */
@Composable internal fun BarChart(title:String,rows:List<Pair<String,Double>>,vertical:Boolean=false) {
    val marks=MaterialTheme.colorScheme.onSurfaceVariant
    val track=MaterialTheme.colorScheme.surfaceContainerHigh
    ContentCard {
        Text(title,style=MaterialTheme.typography.titleLarge,modifier=Modifier.semantics {heading()})
        if(rows.isEmpty() || rows.all {it.second==0.0}) Text(stringResource(R.string.no_chart_data),color=marks)
        else {
            val maximum=rows.maxOf {it.second}.coerceAtLeast(1.0)
            val description=rows.joinToString("; ") {"${it.first}: ${number(it.second)}"}
            Canvas(Modifier.fillMaxWidth().height(if(vertical) 140.dp else (rows.size*26).dp).semantics {contentDescription=description}) {
                if(vertical) {
                    val step=size.width/rows.size
                    rows.forEachIndexed {i,row ->
                        val h=(row.second/maximum*size.height).toFloat()
                        drawRoundRect(marks,Offset(i*step+step*.18f,size.height-h),Size(step*.64f,h),CornerRadius(5.dp.toPx()))
                    }
                } else rows.forEachIndexed {i,row ->
                    val step=size.height/rows.size
                    drawRoundRect(track,Offset(0f,i*step+4),Size(size.width,step-8),CornerRadius(4.dp.toPx()))
                    if(row.second>0) drawRoundRect(marks,Offset(0f,i*step+4),Size((row.second/maximum*size.width).toFloat(),step-8),CornerRadius(4.dp.toPx()))
                }
            }
            if(vertical && LocalConfiguration.current.fontScale<1.5f && rows.size<=7) Row(Modifier.fillMaxWidth()) {
                rows.forEach {Text(it.first,Modifier.weight(1f),style=MaterialTheme.typography.labelSmall,maxLines=1)}
            }
            rows.forEach {row ->Row(Modifier.fillMaxWidth().semantics(mergeDescendants=true) {},horizontalArrangement=Arrangement.spacedBy(12.dp)) {
                Text(row.first,Modifier.weight(1f),style=MaterialTheme.typography.bodyMedium,color=marks)
                Text(number(row.second),style=MaterialTheme.typography.bodyMedium.copy(fontFeatureSettings="tnum"))
            }}
        }
    }
}
@Composable internal fun WeeklyCard(bags:List<JsonObject>) {
    var data by remember {mutableStateOf<JsonObject?>(null)}
    var failed by remember {mutableStateOf(false)}
    LaunchedEffect(bags) {
        failed=false
        try {data=withContext(Dispatchers.Default) {Domain.call("dashboard","bags" to bags).asJsonObject}}
        catch(e:CancellationException) {throw e} catch(_:Exception) {failed=true}
    }
    ContentCard {
        Text(stringResource(R.string.this_week),style=MaterialTheme.typography.titleLarge)
        data?.let {d ->
            Figure("${number(d.number("usedWeek"))} g",stringResource(R.string.used_week))
            Text(stringResource(R.string.week_free_days,d.number("freeDays")!!.toInt()),color=MaterialTheme.colorScheme.onSurfaceVariant)
        }
        if(failed) Text(stringResource(R.string.operation_failed))
    }
}

@Composable internal fun StatsCards(d:JsonObject) {
    val large=LocalConfiguration.current.fontScale>=1.5f
    ContentCard {
        Text(stringResource(R.string.your_collection),style=MaterialTheme.typography.titleLarge)
        Figure(d.number("count")!!.toInt().toString(),stringResource(R.string.items))
        HorizontalDivider(color=MaterialTheme.colorScheme.surfaceContainerHigh)
        if(large) {
            Figure("${number(d.number("grams"))} g",stringResource(R.string.total_weight))
            Figure("${number(d.number("stash"))} g",stringResource(R.string.stash_weight))
        } else Row(horizontalArrangement=Arrangement.spacedBy(24.dp)) {
            Column(Modifier.weight(1f)) {Figure("${number(d.number("grams"))} g",stringResource(R.string.total_weight))}
            Column(Modifier.weight(1f)) {Figure("${number(d.number("stash"))} g",stringResource(R.string.stash_weight))}
        }
    }
    val tiles=listOf(Triple("strains",R.string.strains,Icons.Default.Grass),Triple("growers",R.string.growers,Icons.Default.Agriculture),Triple("averageTHC",R.string.average_thc,Icons.Default.Science),Triple("sessions",R.string.sessions,Icons.Default.Schedule))
    tiles.chunked(if(large) 1 else 2).forEach {row ->Row(horizontalArrangement=Arrangement.spacedBy(12.dp)) {
        row.forEach {(key,label,icon) ->MetricTile(label,number(d.number(key))+(if(key=="averageTHC" && d.number(key)!=null) "%" else ""),icon,Modifier.weight(1f))}
    }}
    val locale=java.util.Locale.getDefault()
    BarChart(stringResource(R.string.monthly_collection),d.array("months").takeLast(6).map {it.asJsonObject.let {v ->
        java.time.Instant.parse(v.text("date")).atZone(java.time.ZoneId.systemDefault()).format(java.time.format.DateTimeFormatter.ofPattern("MMM yy",locale)) to (v.number("count") ?: 0.0)
    }},vertical=true)
    BarChart(stringResource(R.string.growers),d.array("producers").map {it.asJsonObject.let {v ->v.text("name") to (v.number("count") ?: 0.0)}})
    BarChart(stringResource(R.string.thc_spread),d.array("thcBins").filter {it.asJsonObject.number("count")!!>0}.map {it.asJsonObject.let {v ->"${number(v.number("lower"))}–${number(v.number("lower")!!+1)}%" to v.number("count")!!}},vertical=true)
    BarChart(stringResource(R.string.sessions),d.array("methods").map {it.asJsonObject.let {v ->androidx.compose.ui.platform.LocalContext.current.coreText(v.text("name")) to (v.number("count") ?: 0.0)}})
    ContentCard {
        Text(stringResource(R.string.your_totals),style=MaterialTheme.typography.titleLarge)
        listOf("averageHashTHC" to R.string.hash_thc,"averageScore" to R.string.score,"spent" to R.string.spent,"pricePerGram" to R.string.per_gram,"usedToday" to R.string.used_today,"usedWeek" to R.string.used_week,"daysSupply" to R.string.days_supply,"freeDays" to R.string.free_days).forEach {(key,label) ->
            d.number(key)?.let {value ->Metric(label,(if(key=="spent" || key=="pricePerGram") "€ " else "")+number(value)+(if(key=="usedToday" || key=="usedWeek") " g" else if(key=="averageHashTHC") "%" else ""))}
        }
    }
    val context=androidx.compose.ui.platform.LocalContext.current
    listOf("positive" to R.string.effects,"negative" to R.string.downsides,"flavors" to R.string.flavors,"topStrains" to R.string.top_strains,"moodByStrain" to R.string.mood_patterns,"moodByMethod" to R.string.mood_patterns).forEach {(key,title) ->
        if(d.array(key).isNotEmpty()) ContentCard {
            Text(stringResource(title),style=MaterialTheme.typography.titleLarge)
            d.array(key).forEach {row ->val v=row.asJsonObject;Text(context.coreText(v.text("name")));Text(listOfNotNull(v.number("count")?.let(::number),v.number("score")?.let(::number),v.number("change")?.let(::number)).joinToString(" · "),color=MaterialTheme.colorScheme.onSurfaceVariant)}
        }
    }
    Text(stringResource(R.string.patterns_help),style=MaterialTheme.typography.bodySmall,color=MaterialTheme.colorScheme.onSurfaceVariant)
    if(d.array("shops").isNotEmpty()) ContentCard {
        Text(stringResource(R.string.shops),style=MaterialTheme.typography.titleLarge)
        d.array("shops").forEach {s ->val v=s.asJsonObject;Text(v.text("name"));Metric(R.string.spent,"€ ${number(v.number("euros"))}");Metric(R.string.per_gram,"€ ${number(v.number("perGram"))}")}
    }
}

internal fun deckColor(kind:String):Color = Color(when(kind) {
    "challenge"->0xFFB5451C;"duel"->0xFFA31A3B;"vote"->0xFF3D36A6;"everyone"->0xFF0D6B66
    "question"->0xFF6E2987;"dilemma"->0xFF1F5EA8;"quickfire"->0xFF7A5200;"act"->0xFF8A1F6E
    "debate"->0xFF7A2417;"rule","ruleEnd"->0xFF2E3D52;"smoke"->0xFF14542E
    "herd"->0xFF1C5C85;"scale"->0xFF4D388F;"bomb"->0xFFA82E0D
    "mission","missionEnd"->0xFF212133;"standings"->0xFF5C4000;"legendary"->0xFF1A1405
    else->0xFF1B7A47
})
