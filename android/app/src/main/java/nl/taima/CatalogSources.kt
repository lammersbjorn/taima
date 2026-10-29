package nl.taima

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.stringResource

/** Public source links open only on an explicit tap; no collection data is included. */
@Composable internal fun CatalogSources(ids:List<String>) {
    val context=LocalContext.current;val handler=LocalUriHandler.current
    val sources=remember {context.assets.open("strain-sources.json").bufferedReader().use {com.google.gson.JsonParser.parseReader(it).asJsonObject.getAsJsonObject("sources")}}
    ids.forEach {id ->
        val source=sources.getAsJsonObject(id)
        if(source==null) Text(id) else {
            val url=source.text("url");val uri=runCatching {java.net.URI(url)}.getOrNull()
            Text(source.text("record"),style=MaterialTheme.typography.titleSmall)
            if(uri?.scheme in listOf("https","http") && uri?.host!=null) TextButton(onClick={handler.openUri(url)}) {Text(url)}
        }
    }
    if(ids.isEmpty()) Text(stringResource(R.string.no_sources))
}
