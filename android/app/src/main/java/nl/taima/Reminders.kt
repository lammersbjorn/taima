package nl.taima

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.google.gson.JsonObject

/** Shared Swift crossing rules. Notifications contain no collection data. */
object Reminders {
    fun check(context:Context,before:List<JsonObject>,after:List<JsonObject>) {
        val prefs=context.getSharedPreferences("taima",0)
        val core=Core(context)
        val due=core.call("reminders","before" to before,"bags" to after,"weeklyLimit" to prefs.getFloat("limits.weeklyGrams",0f),"lowStashDays" to prefs.getInt("limits.lowStashDays",0)).asJsonArray
        if(due.isEmpty) return
        val manager=NotificationManagerCompat.from(context)
        if(!manager.areNotificationsEnabled()) return
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(NotificationChannel("goals",context.getString(R.string.weekly_reminder),NotificationManager.IMPORTANCE_DEFAULT))
        val open=PendingIntent.getActivity(context,421,Intent(context,MainActivity::class.java).setAction("nl.taima.STASH"),PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        due.forEach {item ->val weekly=item.asString=="weekly"
            manager.notify(if(weekly) 421 else 422,NotificationCompat.Builder(context,"goals").setSmallIcon(R.drawable.ic_launcher)
                .setContentTitle(context.getString(if(weekly) R.string.weekly_reminder else R.string.low_reminder))
                .setContentText(context.getString(R.string.reminder_body)).setContentIntent(open).setAutoCancel(true)
                .setVisibility(NotificationCompat.VISIBILITY_SECRET).build())
        }
    }
}
