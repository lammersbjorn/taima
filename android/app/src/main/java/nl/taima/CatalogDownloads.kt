package nl.taima

import android.content.Context
import java.io.File
import java.net.URL

/** Explicit tap only. Fixed public files, no identifiers, query strings or uploads. */
object CatalogDownloads {
    fun update(context: Context) {
        val work=java.nio.file.Files.createTempDirectory(context.cacheDir.toPath(),"catalog-").toFile()
        try {
            val files=listOf("manifest.json","strains.json","strains-curated.json","growers.json","strain-sources.json")
            files.forEach { name ->
                val connection=URL("https://raw.githubusercontent.com/lammersbjorn/taima/main/catalog/v1/$name").openConnection().apply {connectTimeout=15000;readTimeout=20000;useCaches=false}
                connection.getInputStream().use { input -> File(work,name).outputStream().use {output ->
                    val buffer=ByteArray(8192);var bytes=0
                    while(true) {val n=input.read(buffer);if(n<0) break;bytes+=n;require(bytes<=16*1024*1024);output.write(buffer,0,n)}
                } }
            }
            Domain.call("catalog.verify","directory" to work.path,"build" to BuildConfig.VERSION_CODE)
            val folder=File(context.filesDir,"catalog-${System.currentTimeMillis()}").apply {mkdirs()}
            // Install only after the full public manifest has passed Swift verification.
            files.forEach {name -> File(work,name).copyTo(File(folder,name),true)}
            context.getSharedPreferences("taima",0).edit().putString("catalog.folder",folder.name).commit()
        } finally {work.deleteRecursively()}
    }
}
