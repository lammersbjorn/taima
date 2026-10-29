package nl.taima

import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource

/** The same bundled educational copy as the iPhone tools, resolved via shared resources. */
@Composable internal fun ToolGuides() {
    var expanded by remember {mutableStateOf(false)}
    OutlinedButton(onClick={expanded=!expanded}) {Text(stringResource(R.string.guides))}
    if(!expanded) return
    T("Common home methods")
    listOf("Oven" to "110–120 °C for 30–45 minutes","Sous vide" to "95 °C for 90 minutes, sealed","Butter or oil" to "Below 90 °C for 2–3 hours after decarbing").forEach {(title,detail) ->
        Text(LocalContext.current.coreText(title),style=MaterialTheme.typography.titleMedium);T(detail)
    }
    T("Decarboxylation turns THCA into THC. Spread ground flower thinly on baking paper and keep the oven below 125 °C to protect terpenes. Oven thermostats vary, so an oven thermometer helps.")
    HorizontalDivider()
    T("An estimate. Edibles take 30 minutes to 2 hours to work; many people start with 2.5 to 5 mg and wait before taking more.")
    T("Smoking delivers only part of this THC, often a third or less.")
    HorizontalDivider()
    listOf(
        "Start low" to "Strong bags are common in the Netherlands. Take less, or a lower THC, when you're new, after a break or with a new strain.",
        "Vaping over smoking" to "A dry-herb vaporiser spares your lungs the smoke. Smoking is the most harmful way to use.",
        "Leave out the tobacco" to "Nicotine is very addictive, and mixing it in makes stopping harder. Tobacco-free joints or a vaporiser avoid it.",
        "Don't hold it in" to "Inhaling deeply or holding smoke adds tar, not effect.",
        "Edibles: wait" to "Effects take 30 to 90 minutes and last longer. Wait before taking more; the edible timer can help.",
        "Don't drive" to "Don't drive or use machinery after using. THC slows reactions, and Dutch law sets strict limits.",
        "Don't mix" to "Alcohol and other drugs make the effects stronger and harder to predict.",
        "Take breaks" to "Breaks keep your tolerance down. Using every day is a sign to look at your use.",
        "Pregnancy" to "Don't use when pregnant or breastfeeding."
    ).forEach {(title,detail) ->Text(LocalContext.current.coreText(title),style=MaterialTheme.typography.titleMedium);T(detail)}
    T("After Trimbos guidance. General information, not medical advice.")
}
