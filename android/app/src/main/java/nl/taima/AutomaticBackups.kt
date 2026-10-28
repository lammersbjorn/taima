package nl.taima

import android.content.Context
import android.net.Uri
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.documentfile.provider.DocumentFile
import androidx.work.*
import java.security.KeyStore
import java.util.concurrent.TimeUnit
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Only Android's local key store can unwrap the saved backup passphrase. */
object AutomaticBackups {
    private fun key(): SecretKey {
        val store=KeyStore.getInstance("AndroidKeyStore").apply {load(null)}
        return store.getKey("taima.backup",null) as? SecretKey ?: KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES,"AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder("taima.backup",KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT).setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
        }.generateKey()
    }
    fun enable(context: Context, uri: Uri, passphrase: String) {
        val cipher=Cipher.getInstance("AES/GCM/NoPadding").apply {init(Cipher.ENCRYPT_MODE,key())}
        val wrapped=cipher.doFinal(passphrase.toByteArray(Charsets.UTF_8))
        context.getSharedPreferences("taima",0).edit().putString("backup.folder",uri.toString()).putString("backup.secret",Base64.encodeToString(wrapped,Base64.NO_WRAP)).putString("backup.iv",Base64.encodeToString(cipher.iv,Base64.NO_WRAP)).commit()
        WorkManager.getInstance(context).enqueueUniquePeriodicWork("taima.backup",ExistingPeriodicWorkPolicy.UPDATE,PeriodicWorkRequestBuilder<BackupWorker>(1,TimeUnit.DAYS).build())
    }
    fun disable(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork("taima.backup")
        context.getSharedPreferences("taima",0).edit().remove("backup.folder").remove("backup.secret").remove("backup.iv").apply()
    }
    fun passphrase(context: Context): String {
        val p=context.getSharedPreferences("taima",0)
        val iv=Base64.decode(p.getString("backup.iv",null) ?: error("No backup key"),Base64.NO_WRAP)
        val bytes=Base64.decode(p.getString("backup.secret",null) ?: error("No backup key"),Base64.NO_WRAP)
        return Cipher.getInstance("AES/GCM/NoPadding").apply {init(Cipher.DECRYPT_MODE,key(),GCMParameterSpec(128,iv))}.doFinal(bytes).toString(Charsets.UTF_8)
    }
}
class BackupWorker(context: Context,params: WorkerParameters): CoroutineWorker(context,params) {
    override suspend fun doWork(): Result = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
        val context=applicationContext
        val prefs=context.getSharedPreferences("taima",0)
        val folder=prefs.getString("backup.folder",null) ?: return@withContext Result.success()
        try {
            Domain.core=Core(context)
            val tree=DocumentFile.fromTreeUri(context,Uri.parse(folder)) ?: error("Folder unavailable")
            val file=tree.createFile("application/octet-stream","Taima-${java.time.LocalDate.now()}.taimabackup") ?: error("Folder unavailable")
            try {
                BagDatabase(context).use {db -> context.contentResolver.openOutputStream(file.uri)!!.use {BackupFiles.export(context,db,it,AutomaticBackups.passphrase(context))}}
            } catch(e:Exception) {file.delete();throw e}
            prefs.edit().putString("backup.last",timestamp()).apply();Result.success()
        } catch(e:kotlinx.coroutines.CancellationException) {throw e} catch(_:Exception) {if(runAttemptCount<2) Result.retry() else Result.failure()}
    }
}
