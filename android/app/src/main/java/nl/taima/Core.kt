package nl.taima

import android.content.Context
import com.google.gson.*
import java.io.File
import java.time.Instant
import java.util.Locale

/** The only domain entry point used by the shipping app. Call on Dispatchers.IO. */
class Core(context: Context) {
    private val resources = File(context.filesDir, "swift-resources-${BuildConfig.VERSION_CODE}-${context.packageManager.getPackageInfo(context.packageName,0).lastUpdateTime}").apply { mkdirs() }
    init {
        synchronized(Core::class.java) { listOf("party-content.json", "strains.json", "strains-curated.json").forEach { name ->
            if (!File(resources,name).exists()) context.assets.open(name).use { input -> File(resources, name).outputStream().use { output -> input.copyTo(output) } }
        }
        }
        NativeBridge.load()
    }
    fun call(op: String, vararg fields: Pair<String, Any?>): JsonElement {
        val request = obj(*fields).apply {
            addProperty("version",1); addProperty("op",op)
            addProperty("language",Locale.getDefault().language)
            addProperty("locale",Locale.getDefault().toLanguageTag())
            addProperty("timeZone",java.time.ZoneId.systemDefault().id)
            addProperty("resourceDirectory",resources.absolutePath)
        }
        val envelope = JsonParser.parseString(NativeBridge.call(request.toString().toByteArray(Charsets.UTF_8)).toString(Charsets.UTF_8)).asJsonObject
        check(envelope["ok"].asBoolean) { envelope["error"].toString() }
        return envelope["result"]
    }
    private val catalogFolder: File
        get() = contextForCatalog.getSharedPreferences("taima",0).getString("catalog.folder",null)?.let { File(contextForCatalog.filesDir,it) } ?: resources
    private val contextForCatalog = context.applicationContext
    fun catalog(query: String = "", name: String = "", bags: List<JsonObject> = emptyList()): JsonObject = call("catalog", "query" to query, "name" to name, "bags" to bags,
        "curated" to File(catalogFolder,"strains-curated.json").readText(), "community" to File(catalogFolder,"strains.json").readText()).asJsonObject
}
fun obj(vararg fields: Pair<String, Any?>) = JsonObject().apply { fields.forEach { (key,value) -> if(value!=null) add(key, Gson().toJsonTree(value)) } }
fun JsonObject.text(key: String): String = get(key)?.takeUnless { it.isJsonNull }?.asString ?: ""
fun JsonObject.number(key: String): Double? = get(key)?.takeUnless { it.isJsonNull }?.asDouble
fun JsonObject.array(key: String): List<JsonElement> = getAsJsonArray(key)?.toList().orEmpty()
fun timestamp() = Instant.now().truncatedTo(java.time.temporal.ChronoUnit.SECONDS).toString()

/** Source keys from Swift resolve to Android resources. Never apply English plural rules. */
fun android.content.Context.coreText(key: String): String {
    val digest = java.security.MessageDigest.getInstance("SHA-256").digest(key.toByteArray()).joinToString("") { "%02x".format(it) }.take(16)
    val id = resources.getIdentifier("core_$digest", "string", packageName)
    return if (id != 0) getString(id) else key
}
object Domain {
    lateinit var core: Core
    fun call(op: String, vararg fields: Pair<String, Any?>) = core.call(op,*fields)
    fun view(bag: JsonObject) = call("bag.view", "bag" to bag).asJsonObject
    fun remaining(bag: JsonObject) = view(bag).number("remaining") ?: 0.0
    fun amount(text: String) = call("number.parse", "text" to text).takeUnless { it.isJsonNull }?.asDouble
}
