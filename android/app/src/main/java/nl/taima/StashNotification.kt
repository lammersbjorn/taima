package nl.taima

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

/** Opt-in, discreet ongoing stash access. Every action goes through the app's unlock screen. */
object StashNotification {
    private const val id=420
    fun update(context:Context) {
        val prefs=context.getSharedPreferences("taima",0)
        val manager=NotificationManagerCompat.from(context)
        if(!prefs.getBoolean("stash.notification",false)) {manager.cancel(id);return}
        if(android.os.Build.VERSION.SDK_INT>=33 && ContextCompat.checkSelfPermission(context,android.Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED) return
        val bag=BagDatabase(context).use {db ->db.all().firstOrNull {it.text("id")==prefs.getString("inUse",null)}}
        if(bag==null || (Core(context).call("bag.view","bag" to bag).asJsonObject.number("remaining") ?: 0.0)<=0) {manager.cancel(id);return}
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(NotificationChannel("stash",context.getString(R.string.stash),NotificationManager.IMPORTANCE_LOW))
        fun open(action:String,request:Int)=PendingIntent.getActivity(context,request,Intent(context,MainActivity::class.java).setAction(action),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification=NotificationCompat.Builder(context,"stash").setSmallIcon(R.drawable.ic_launcher)
            .setContentTitle(context.getString(R.string.app_name)).setContentText(context.getString(R.string.stash_notification_help))
            .setVisibility(NotificationCompat.VISIBILITY_SECRET).setOngoing(true).setOnlyAlertOnce(true)
            .setContentIntent(open("nl.taima.STASH",0))
            .addAction(0,context.getString(R.string.log_session),open("nl.taima.LOG",1)).build()
        manager.notify(id,notification)
    }
}
class StashTile : android.service.quicksettings.TileService() {
    override fun onStartListening() {super.onStartListening();qsTile?.apply {label=getString(R.string.app_name);state=android.service.quicksettings.Tile.STATE_INACTIVE;updateTile()}}
    override fun onClick() {
        super.onClick()
        val intent=Intent(this,MainActivity::class.java).setAction("nl.taima.STASH").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if(android.os.Build.VERSION.SDK_INT>=34) startActivityAndCollapse(PendingIntent.getActivity(this,42,intent,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        else { @Suppress("DEPRECATION") startActivityAndCollapse(intent) }
    }
}
