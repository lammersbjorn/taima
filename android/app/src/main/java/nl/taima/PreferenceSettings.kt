package nl.taima

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.*

@Composable internal fun PreferenceSettings(db:BagDatabase,busy:Boolean,action:(()->Unit)->Unit,onReset:()->Unit) {
    val context=LocalContext.current;val prefs=remember {context.getSharedPreferences("taima",0)}
    var intro by remember {mutableStateOf(false)};var highlights by remember {mutableStateOf(false)}
    var stock by remember {mutableStateOf(prefs.getString("editor.defaultStock","empty")!!)}
    var weekly by remember {mutableStateOf(number(prefs.getFloat("limits.weeklyGrams",0f).toDouble()))}
    var low by remember {mutableStateOf(prefs.getInt("limits.lowStashDays",0).toString())}
    var invalid by remember {mutableStateOf(false)}
    var confirm by remember {mutableStateOf(false)};var typed by remember {mutableStateOf("")}
    val permission=androidx.activity.compose.rememberLauncherForActivityResult(androidx.activity.result.contract.ActivityResultContracts.RequestPermission()) {}
    Column(verticalArrangement=Arrangement.spacedBy(16.dp)) {
        Choice(R.string.default_stock,stock,listOf("full" to R.string.full,"open" to R.string.open,"empty" to R.string.empty)) {stock=it;prefs.edit().putString("editor.defaultStock",it).apply()}
        LearningSettings();EntryReviewScreen(db,action)
        HorizontalDivider()
        Field(R.string.weekly_limit,weekly,{weekly=it},true);Field(R.string.low_days,low,{low=it},true)
        Text(stringResource(R.string.reminders_help))
        Button(enabled=!busy,onClick={
            val grams=Domain.amount(weekly);val days=low.toIntOrNull()
            invalid=grams==null || grams !in 0.0..50.0 || days==null || days !in 0..365
            if(!invalid) {prefs.edit().putFloat("limits.weeklyGrams",grams!!.toFloat()).putInt("limits.lowStashDays",days!!).apply();if(android.os.Build.VERSION.SDK_INT>=33) permission.launch(android.Manifest.permission.POST_NOTIFICATIONS)}
        }) {Text(stringResource(R.string.save_preferences))}
        if(invalid) Text(stringResource(R.string.invalid_fields))
        TextButton(onClick={intro=true}) {Text(stringResource(R.string.show_intro))}
        TextButton(onClick={highlights=true}) {Text(stringResource(R.string.whats_new))}
        TextButton(onClick={context.startActivity(Intent(android.provider.Settings.ACTION_APP_LOCALE_SETTINGS,Uri.parse("package:${context.packageName}")))},enabled=android.os.Build.VERSION.SDK_INT>=33) {Text(stringResource(R.string.app_language))}
        TextButton(onClick={context.startActivity(Intent(Intent.ACTION_VIEW,Uri.parse("https://github.com/ImranR98/Obtainium")))}) {Text(stringResource(R.string.app_updates))}
        Text("${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})")
        TextButton(enabled=!busy,onClick={confirm=true;typed=""}) {Text(stringResource(R.string.delete_data),color=MaterialTheme.colorScheme.error)}
    }
    if(intro) Welcome(false) {intro=false}
    if(highlights) Welcome(true) {highlights=false}
    if(confirm) AlertDialog(onDismissRequest={confirm=false},title={Text(stringResource(R.string.delete_data))},text={Column {
        Text(stringResource(R.string.erase_help));OutlinedTextField(typed,{typed=it},label={Text("DELETE")})
    }},confirmButton={TextButton(enabled=typed=="DELETE" && !busy,onClick={action {AppData.erase(context,db);confirm=false;onReset()}}) {Text(stringResource(R.string.delete_data))}},dismissButton={TextButton(onClick={confirm=false}) {Text(stringResource(R.string.cancel))}})
}

object AppData {
    fun erase(context:android.content.Context,db:BagDatabase) {
        AutomaticBackups.disable(context)
        db.eraseAll()
        context.getSharedPreferences("taima",0).edit().clear().commit()
        context.getSystemService(android.app.NotificationManager::class.java).cancelAll()
        val store=java.security.KeyStore.getInstance("AndroidKeyStore").apply {load(null)}
        if(store.containsAlias("taima.backup")) store.deleteEntry("taima.backup")
        context.contentResolver.persistedUriPermissions.forEach {permission ->
            val flags=(if(permission.isReadPermission) Intent.FLAG_GRANT_READ_URI_PERMISSION else 0) or (if(permission.isWritePermission) Intent.FLAG_GRANT_WRITE_URI_PERMISSION else 0)
            context.contentResolver.releasePersistableUriPermission(permission.uri,flags)
        }
        // All internal files belong to Taima; exported SAF backups live elsewhere.
        context.cacheDir.listFiles().orEmpty().forEach {it.deleteRecursively()}
        context.filesDir.listFiles().orEmpty().forEach {it.deleteRecursively()}
        Domain.core=Core(context)
    }
}
