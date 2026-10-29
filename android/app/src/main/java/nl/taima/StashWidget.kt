package nl.taima

import android.content.Context
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.action.actionStartActivity
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.action.ActionParameters
import androidx.glance.layout.Column
import androidx.glance.layout.padding
import androidx.glance.text.Text
import androidx.glance.Button
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

private data class WidgetSnapshot(val name:String?,val remaining:Double?,val discreet:Boolean,val edible:Boolean)
class StashWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val snapshot=withContext(Dispatchers.IO) {
            val core=Core(context)
            BagDatabase(context).use { db ->
                val bags=db.all();val prefs=context.getSharedPreferences("taima",0)
                val current=bags.firstOrNull {it.text("id")==prefs.getString("inUse",null)}
                val remaining=current?.let {core.call("bag.view","bag" to it).asJsonObject.number("remaining")}
                WidgetSnapshot(current?.text("name"),remaining,prefs.getBoolean("discreet",false),current?.let(::isEdible)==true)
            }
        }
        provideContent {
            Column(GlanceModifier.padding(16.dp)) {
                Text(context.getString(R.string.stash))
                if(!snapshot.discreet) Text(snapshot.name ?: context.getString(R.string.no_stash))
                Text(if(snapshot.edible) context.getString(R.string.piece_amount,number(snapshot.remaining)) else "${number(snapshot.remaining)} g")
                Button(context.getString(R.string.open_taima), actionStartActivity<MainActivity>())
                if(snapshot.remaining!=null && snapshot.remaining >= (if(snapshot.edible) 0.5 else 0.1)) Button(context.getString(if(snapshot.edible) R.string.ate_half else R.string.quick_widget),actionRunCallback<QuickLog>())
            }
        }
    }
}
class StashWidgetReceiver : GlanceAppWidgetReceiver() { override val glanceAppWidget=StashWidget() }
class QuickLog : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        withContext(Dispatchers.IO) {
            val core=Core(context)
            BagDatabase(context).use { db ->
                val id=context.getSharedPreferences("taima",0).getString("inUse",null) ?: return@use
                db.mutate(id) { bag ->
                    val amount=if(isEdible(bag)) 0.5 else 0.1
                    if((core.call("bag.view","bag" to bag).asJsonObject.number("remaining") ?: 0.0)<amount) bag
                    else core.call("bag.use","bag" to bag,"amount" to amount).asJsonObject
                }
            }
        }
        StashWidget().update(context,glanceId)
    }
}
