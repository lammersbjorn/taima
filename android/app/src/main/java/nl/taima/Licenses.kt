package nl.taima

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import kotlinx.coroutines.*

@Composable internal fun Licenses() {
    val context=LocalContext.current
    var show by remember {mutableStateOf(false)}
    var name by remember {mutableStateOf("SOURCES.txt")}
    var text by remember {mutableStateOf("")}
    LaunchedEffect(show,name) {if(show) text=withContext(Dispatchers.IO) {context.assets.open("licenses/$name").bufferedReader().use {it.readText()}}}
    OutlinedButton(onClick={show=true}) {Text(stringResource(R.string.licenses))}
    if(show) androidx.compose.ui.window.Dialog(onDismissRequest={show=false},properties=androidx.compose.ui.window.DialogProperties(usePlatformDefaultWidth=false)) {
        Surface(Modifier.fillMaxSize()) {Page {
            Text(stringResource(R.string.licenses),style=MaterialTheme.typography.headlineSmall)
            TextButton(onClick={show=false}) {Text(stringResource(R.string.back))}
            FlowRow {listOf("SOURCES.txt","Tesseract4Android-LICENSE.txt","Tesseract-LICENSE.txt","Leptonica-LICENSE.txt","libpng-LICENSE.txt","libjpeg-README.txt").forEach {file ->TextButton(onClick={name=file}) {Text(file)}}}
            Text(text)
        }}
    }
}
