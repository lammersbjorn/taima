package nl.taima

import android.content.Context
import java.io.*

/** SAF streams are staged privately. Swift owns both archive formats and crypto. */
object BackupFiles {
    fun export(context: Context, db: BagDatabase, output: OutputStream, passphrase: String) {
        val work = java.nio.file.Files.createTempDirectory(context.cacheDir.toPath(),"backup-").toFile()
        try {
            val photos=File(work,"photos").apply { mkdirs() }
            db.exportPhotos(photos)
            val file=File(work,"export.taimabackup")
            Domain.call("backup.write", "manifest" to db.snapshot(), "path" to file.path, "photoDirectory" to photos.path, "passphrase" to passphrase)
            file.inputStream().use { it.copyTo(output) }
        } finally { work.deleteRecursively() }
    }
    fun restore(context: Context, db: BagDatabase, input: InputStream, passphrase: String) {
        val work=java.nio.file.Files.createTempDirectory(context.cacheDir.toPath(),"restore-").toFile()
        try {
            val file=File(work,"import.taimabackup");file.outputStream().use { input.copyTo(it) }
            val photos=File(work,"photos").apply { mkdirs() }
            val manifest=Domain.call("backup.read", "path" to file.path,"photoDirectory" to photos.path,"passphrase" to passphrase).asJsonObject
            db.restoreDirectory(manifest,photos)
        } finally { work.deleteRecursively() }
    }
}
