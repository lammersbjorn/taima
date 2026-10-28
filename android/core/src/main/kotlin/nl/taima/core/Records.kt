package nl.taima.core

import com.google.gson.*
import java.time.Instant
import java.util.Locale
import java.util.UUID

/** JSON documents retain fields that this trial does not expose in its editor. */
object Records {
    fun timestamp(now: Instant = Instant.now()) = now.truncatedTo(java.time.temporal.ChronoUnit.SECONDS).toString()
    private val gson = GsonBuilder().disableHtmlEscaping().create()
    fun parse(text: String): JsonObject = JsonParser.parseString(text).asJsonObject
    fun canonical(value: JsonElement): String {
        fun sorted(v: JsonElement): JsonElement = when {
            v.isJsonObject -> JsonObject().also { out -> v.asJsonObject.keySet().sorted().forEach { out.add(it, sorted(v.asJsonObject[it])) } }
            v.isJsonArray -> JsonArray().also { out -> v.asJsonArray.forEach { out.add(sorted(it)) } }
            else -> v
        }
        return gson.toJson(sorted(value))
    }
    fun newBag(now: Instant = Instant.now()): JsonObject = parse("""{"id":"${UUID.randomUUID().toString().uppercase()}","name":"","notes":"","recognizedText":"","collectedOn":"${timestamp(now)}","createdAt":"${timestamp(now)}","updatedAt":"${timestamp(now)}","stockState":"full","productForm":"bag","usageLog":[]}""")
    fun validate(bag: JsonObject, requireName: Boolean = true) {
        UUID.fromString(bag.text("id"))
        require(bag.has("name") && bag["name"].asJsonPrimitive.isString) { "name" }
        if (requireName) require(bag.text("name").trim().isNotEmpty()) { "name" }
        listOf("collectedOn", "createdAt", "updatedAt").forEach { Instant.parse(bag.text(it)) }
        listOf("notes", "recognizedText").forEach { require(bag.has(it) && bag[it].isJsonPrimitive && bag[it].asJsonPrimitive.isString) }
        listOf("grams", "remainingGrams", "priceEuros").forEach { key -> bag.number(key)?.let { require(it.isFinite() && it >= 0) { key } } }
        require(bag.number("remainingGrams")?.let { it <= (bag.number("grams") ?: it) } ?: true)
        listOf("thc", "cbd").forEach { key -> bag.getAsJsonObject(key)?.number("percent")?.let { require(it.isFinite() && it in 0.0..100.0) { key } } }
    }
    fun normalize(text: String): String = try {
        val bag = parse(text)
        try { validate(bag); bag.addProperty("name", bag.text("name").trim()); canonical(JsonObject().also { it.add("record", bag) }) }
        catch (_: Exception) { """{"error":"invalidRecord"}""" }
    } catch (_: Exception) { """{"error":"invalidJSON"}""" }
    fun remaining(bag: JsonObject): Double = when (bag.text("stockState")) {
        "full" -> bag.number("grams") ?: 0.0
        "open" -> bag.number("remainingGrams") ?: bag.number("grams") ?: 0.0
        else -> 0.0
    }
    fun log(bag: JsonObject, amount: Double, method: String, note: String, now: Instant = Instant.now()): JsonObject {
        require(amount.isFinite() && amount > 0 && amount <= remaining(bag))
        return bag.deepCopy().also {
            val rest = (remaining(bag) - amount).coerceAtLeast(0.0)
            it.addProperty("remainingGrams", rest); it.addProperty("stockState", if (rest == 0.0) "empty" else "open")
            val log = it.getAsJsonArray("usageLog") ?: JsonArray().also { a -> it.add("usageLog", a) }
            log.add(JsonObject().apply { addProperty("id", UUID.randomUUID().toString().uppercase()); addProperty("date", timestamp(now)); addProperty("grams", amount); addProperty("method", method); addProperty("note", note) })
            it.addProperty("updatedAt", timestamp(now))
        }
    }
}
fun JsonObject.text(key: String): String = get(key)?.takeUnless { it.isJsonNull }?.asString ?: ""
fun JsonObject.number(key: String): Double? = get(key)?.takeUnless { it.isJsonNull }?.asDouble

/** No grouping or separator substitution: ambiguous numbers never become saved amounts. */
object AmountInput {
    fun parse(text: String, locale: Locale): Double? {
        val separator = java.text.DecimalFormatSymbols.getInstance(locale).decimalSeparator
        val value = text.trim()
        val parts = value.split(separator)
        if (parts.size > 2 || parts.any { it.isEmpty() || !it.all { c -> c in '0'..'9' } }) return null
        return value.replace(separator, '.').toDoubleOrNull()?.takeIf { it.isFinite() && it >= 0 }
    }
}
