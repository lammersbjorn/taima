package nl.taima

import android.content.Context
import com.google.gson.JsonObject
import com.google.gson.JsonParser

/** Only the shared Swift CorrectionMemory decides what to learn or apply. */
object LabelLearning {
    fun apply(context:Context, bag:JsonObject):JsonObject {
        val prefs=context.getSharedPreferences("taima",0)
        return bag.deepCopy().apply {
            BagDatabase(context).use {db ->db.learnedProducer(this)?.let {addProperty("producer",it)}}
            addProperty("androidReadName",text("name"))
            addProperty("stockState",prefs.getString("editor.defaultStock","empty"))
            if(prefs.getBoolean("learning.enabled",true)) {
                val memory=prefs.getString("learning.memory",null)?.let {JsonParser.parseString(it)}
                addProperty("name",Domain.call("learning","memory" to memory,"name" to text("name")).asJsonObject.text("name"))
            }
        }
    }
    fun learn(context:Context, original:JsonObject, saved:JsonObject) {
        val prefs=context.getSharedPreferences("taima",0)
        if(!prefs.getBoolean("learning.enabled",true) || !original.has("androidReadName")) return
        synchronized(this) {
            val memory=prefs.getString("learning.memory",null)?.let {JsonParser.parseString(it)}
            val result=Domain.call("learning","action" to "learn","memory" to memory,"read" to original.text("androidReadName"),"saved" to saved.text("name")).asJsonObject
            prefs.edit().putString("learning.memory",result["memory"].toString()).apply()
        }
    }
}
