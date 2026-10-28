package nl.taima.core

import com.google.gson.JsonObject
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import java.util.Locale

object CSV {
    val headers = "name,producer,form,type,thc,cbd,grams,stock,remaining_g,harvested,packed,collected,price_eur,shop,town,score_of_10,effects,downsides,flavours,sessions,product_id,sku,ean,notes".split(',')
    private fun title(s: String) = s.replaceFirstChar { it.titlecase(Locale.ROOT) }
    private fun potency(b: JsonObject, key: String): String {
        val p = b.getAsJsonObject(key) ?: return ""
        val format = java.text.DecimalFormat("0.#", java.text.DecimalFormatSymbols(Locale.ROOT))
        return (if (p.get("isUpperBound")?.asBoolean == true) "<" else "") + (p.number("lowerBound")?.let { format.format(it) + "–" } ?: "") + format.format(p.number("percent")) + "%"
    }
    fun make(bags: List<JsonObject>): String = (listOf(headers.joinToString(",")) + bags.map { b ->
        fun num(k: String) = b.number(k)?.toString() ?: ""
        fun day(k: String) = b.text(k).takeIf { it.isNotEmpty() }?.let { Instant.parse(it).atOffset(ZoneOffset.UTC).toLocalDate().toString() } ?: ""
        fun tags(k: String) = b.getAsJsonArray(k)?.joinToString("; ") { it.asString } ?: ""
        val form = mapOf("bag" to "Bag", "jar" to "Jar", "preroll" to "Prerolls", "hash" to "Hash")[b.text("productForm")] ?: "Bag"
        val stock = b.text("stockState").ifEmpty { "empty" }
        listOf(b.text("name"), b.text("producer"), form, title(b.text("strainType")), potency(b,"thc"), potency(b,"cbd"), num("grams"), title(stock), if (stock == "empty") "" else Records.remaining(b).toString(), day("harvestedOn"), day("packedOn"), day("collectedOn"), num("priceEuros"), b.text("shop"), b.text("shopCity"), num("score").ifEmpty { b.number("rating")?.let { (it * 2).toString() } ?: "" }, tags("effects"), tags("sideEffects"), tags("flavors"), (b.getAsJsonArray("usageLog")?.size() ?: 0).toString(), b.text("productID"), b.text("sku"), b.text("ean"), b.text("notes")).joinToString(",", transform = ::escape)
    }).joinToString("\n", postfix = "\n")
    private fun escape(input: String): String {
        var s = input
        if (s.firstOrNull() in listOf('=', '+', '-', '@', '\t', '\r') && s.toDoubleOrNull() == null) s = "'$s"
        return if (s.any { it in ",\"\n\r" }) "\"${s.replace("\"", "\"\"")}\"" else s
    }
    private fun rows(text: String, separator: Char): List<List<String>> {
        val rows = mutableListOf<List<String>>(); val row = mutableListOf<String>(); val field = StringBuilder(); var quoted = false; var i = 0
        while (i < text.length) {
            val c = text[i++]
            when {
                c == '"' -> if (quoted && i < text.length && text[i] == '"') { field.append('"'); i++ } else quoted = !quoted
                !quoted && c == separator -> { row.add(field.toString()); field.clear() }
                !quoted && (c == '\n' || c == '\r') -> { if(c == '\r' && i < text.length && text[i] == '\n') i++; row.add(field.toString()); field.clear(); if (row.size != 1 || row[0].isNotEmpty()) rows.add(row.toList()); row.clear() }
                else -> field.append(c)
            }
        }
        if (field.isNotEmpty() || row.isNotEmpty()) { row.add(field.toString()); rows.add(row.toList()) }
        return rows
    }
    fun parse(input: String): List<JsonObject> {
        val text = input.removePrefix("\uFEFF"); val first = text.lineSequence().firstOrNull() ?: return emptyList()
        val rows = rows(text, if(first.count { it == ';' } > first.count { it == ',' }) ';' else ',')
        if (rows.isEmpty()) return emptyList()
        val header = rows.first().map { it.trim().lowercase(Locale.ROOT) }
        return rows.drop(1).mapNotNull { row ->
            fun value(key: String) = row.getOrNull(header.indexOf(key))?.trim()?.removePrefix("'")?.takeIf { it.isNotEmpty() }
            fun number(key: String) = value(key)?.replace(',', '.')?.toDoubleOrNull()?.takeIf { it.isFinite() }
            val name = value("name") ?: return@mapNotNull null
            Records.newBag().apply {
                addProperty("name", name); addProperty("stockState", "empty")
                mapOf("producer" to "producer", "shop" to "shop", "town" to "shopCity", "product_id" to "productID", "sku" to "sku", "ean" to "ean", "notes" to "notes").forEach { (csv, json) -> value(csv)?.let { addProperty(json, it) } }
                mapOf("grams" to "grams", "price_eur" to "priceEuros", "score_of_10" to "score").forEach { (csv,json) -> number(csv)?.let { addProperty(json,it) } }
                if (!has("score")) number("rating")?.let { addProperty("score", it * 2) }
                value("form")?.let { addProperty("productForm", mapOf("bag" to "bag", "jar" to "jar", "prerolls" to "preroll", "hash" to "hash")[it.lowercase(Locale.ROOT)] ?: "bag") }
                value("type")?.let { addProperty("strainType", it.lowercase(Locale.ROOT)) }
                mapOf("collected" to "collectedOn", "harvested" to "harvestedOn", "packed" to "packedOn").forEach { (csv,json) -> value(csv)?.let { raw -> runCatching { LocalDate.parse(raw).atStartOfDay(ZoneOffset.UTC).toInstant().toString() }.getOrNull()?.let { addProperty(json,it) } } }
                listOf("thc", "cbd").forEach { k -> value(k)?.let { v -> v.removePrefix("<").removeSuffix("%").replace(',','.').toDoubleOrNull()?.let { n -> add(k, JsonObject().apply { addProperty("percent",n); addProperty("isUpperBound",v.startsWith('<')) }) } } }
                mapOf("effects" to "effects", "downsides" to "sideEffects", "flavours" to "flavors").forEach { (csv,json) -> value(csv)?.let { v -> add(json, com.google.gson.JsonArray().apply { v.split(';').map(String::trim).filter(String::isNotEmpty).forEach(::add) }) } }
            }
        }
    }
}
