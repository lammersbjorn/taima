package nl.taima

import androidx.compose.runtime.Composable
import androidx.compose.ui.res.stringResource
import com.google.gson.JsonObject

internal fun isEdible(bag: JsonObject) = bag.text("productForm")=="edible"
internal fun amountLabel(context:android.content.Context,bag:JsonObject,amount:Double?):String =
    if(isEdible(bag)) (if(amount==1.0) context.getString(R.string.one_piece) else context.getString(R.string.piece_amount,number(amount))) else "${number(amount)} g"
@Composable internal fun amountLabel(bag:JsonObject,amount:Double?):String =
    amountLabel(androidx.compose.ui.platform.LocalContext.current,bag,amount)

internal fun editorValues(bag: JsonObject): Map<String,String> = buildMap {
    bag.entrySet().forEach { (key,value) -> if(value.isJsonPrimitive) put(key,value.asString) }
    listOf("thc","cbd").forEach { key ->
        val potency=bag.getAsJsonObject(key)
        put(key,potency?.number("percent")?.let(::number).orEmpty())
        put(key+"Lower",potency?.number("lowerBound")?.let(::number).orEmpty())
        put(key+"Upper",potency?.text("isUpperBound") ?: "false")
        put(key+"Basis",potency?.text("basis").orEmpty())
    }
    listOf("grams","remainingGrams","priceEuros","score","unitCount","thcMilligrams").forEach {put(it,bag.number(it)?.let(::number).orEmpty())}
    listOf("harvestedOn","packedOn","bestBeforeOn","collectedOn").forEach {key ->
        put(key,runCatching {java.time.Instant.parse(bag.text(key)).atZone(java.time.ZoneId.systemDefault()).toLocalDate().toString()}.getOrDefault(""))
    }
    listOf("effects","sideEffects","flavors").forEach {put(it,bag.array(it).joinToString("; ") {v->v.asString})}
}

internal fun formLabel(form:String) = when(form) {
    "jar"->R.string.jar;"preroll"->R.string.preroll;"hash"->R.string.hash;"rosin"->R.string.rosin;"edible"->R.string.edibles;else->R.string.bag
}
