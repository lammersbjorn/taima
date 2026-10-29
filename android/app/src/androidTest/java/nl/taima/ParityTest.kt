package nl.taima

import android.content.res.Configuration
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.google.gson.JsonObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.Locale

/** Mandatory shipping JNI contracts. No Assume/skipping when a library is absent. */
@RunWith(AndroidJUnit4::class)
class ParityTest {
    private val instrumentation=InstrumentationRegistry.getInstrumentation()
    private val context=instrumentation.targetContext
    private fun fixture(name:String)=instrumentation.context.assets.open(name).use {it.readBytes()}
    @Test fun nativeContractAndArchiveRoundTrip() {
        val core=Core(context)
        val root=java.nio.file.Files.createTempDirectory(context.cacheDir.toPath(),"parity-").toFile()
        val dbName="parity-${java.util.UUID.randomUUID()}.db"
        try {
            val photos=File(root,"photos").apply {mkdirs()}
            for((file,passphrase) in listOf("plain.taimabackup" to "","encrypted.taimabackup" to "taima-é-🌿")) {
                val input=File(root,file).apply {writeBytes(fixture(file))}
                val manifest=core.call("backup.read","path" to input.path,"photoDirectory" to photos.path,"passphrase" to passphrase).asJsonObject
                assertEquals(com.google.gson.JsonParser.parseString(fixture("record.json").toString(Charsets.UTF_8)),manifest.getAsJsonArray("bags")[0])
                BagDatabase(context,dbName).use {db ->
                    db.restoreBackup(manifest,photos.listFiles()!!.associate {it.name to it.readBytes()})
                    assertArrayEquals(fixture("photo.heic"),db.photo("00000000-0000-4000-8000-000000000003.heic"))
                    val csv=core.call("csv.export","bags" to db.all()).asString
                    assertEquals(fixture("collection.csv").toString(Charsets.UTF_8),csv)
                }
                val output=File(root,"roundtrip.taimabackup")
                core.call("backup.write","path" to output.path,"photoDirectory" to photos.path,"manifest" to manifest,"passphrase" to passphrase)
                assertEquals(manifest,core.call("backup.read","path" to output.path,"photoDirectory" to photos.path,"passphrase" to passphrase))
            }
        } finally {root.deleteRecursively();context.deleteDatabase(dbName)}
    }
    @Test fun nativeDecimalRulesAndQuantityResources() {
        val original=Locale.getDefault()
        try {for(tag in listOf("nl-NL","de-DE","en-US")) {
            val locale=Locale.forLanguageTag(tag);Locale.setDefault(locale)
            val core=Core(context)
            assertEquals(1.25,core.call("number.parse","text" to if(locale.language=="en") "1.25" else "1,25").asDouble,0.0)
            assertTrue(core.call("number.parse","text" to "1,234.5").isJsonNull)
        }} finally {Locale.setDefault(original)}
        val en=context.createConfigurationContext(Configuration(context.resources.configuration).apply {setLocale(Locale.ENGLISH)})
        val nl=context.createConfigurationContext(Configuration(context.resources.configuration).apply {setLocale(Locale.forLanguageTag("nl"))})
        assertEquals("1 jar",en.resources.getQuantityString(R.plurals.jar_count,1,1))
        assertEquals("2 jars",en.resources.getQuantityString(R.plurals.jar_count,2,2))
        assertEquals("1 potje",nl.resources.getQuantityString(R.plurals.jar_count,1,1))
        assertEquals("2 potjes",nl.resources.getQuantityString(R.plurals.jar_count,2,2))
    }
    @Test fun appleMadePhotoBackupReturnsThroughAndroid() {
        val core=Core(context)
        val root=java.nio.file.Files.createTempDirectory(context.cacheDir.toPath(),"photo-parity-").toFile()
        try {
            val input=File(root,"apple-photo.taimabackup").apply {writeBytes(fixture("apple-photo.taimabackup"))}
            val photos=File(root,"photos").apply {mkdirs()}
            val manifest=core.call("backup.read","path" to input.path,"photoDirectory" to photos.path,"passphrase" to "synthetic-photo-only").asJsonObject
            assertEquals(com.google.gson.JsonParser.parseString(fixture("photo-manifest.json").toString(Charsets.UTF_8)),manifest)
            val edible=manifest.array("bags").map {it.asJsonObject}.first {it.text("productForm")=="edible"}
            assertEquals(3.5,core.call("bag.view","bag" to edible).asJsonObject.number("remaining")!!,0.0)
            assertEquals(7.5,edible.number("thcMilligrams")!!,0.0)
            photos.listFiles()!!.forEach {photo ->
                val bitmap=android.graphics.BitmapFactory.decodeFile(photo.path)
                assertNotNull(bitmap);bitmap?.recycle()
            }
            // Retained solely for the explicit Apple return-import test, never app storage.
            core.call("backup.write","path" to File(context.cacheDir,"synthetic-android-return.taimabackup").path,
                "photoDirectory" to photos.path,"manifest" to manifest,"passphrase" to "synthetic-photo-only")
        } finally {root.deleteRecursively()}
    }

    @Test fun concurrentEditsFailBeforeReplacingTheSavedItem() {
        val name="edit-race-${java.util.UUID.randomUUID()}.db"
        try {BagDatabase(context,name).use {db ->
            val original=com.google.gson.JsonParser.parseString(fixture("record.json").toString(Charsets.UTF_8)).asJsonObject
            db.put(original)
            val changed=original.deepCopy().apply {addProperty("notes","Synthetic concurrent change")}
            db.put(changed)
            assertThrows(ConcurrentEdit::class.java) {db.transaction {db.verifyEditBaseline(original,true);db.put(original)}}
            assertEquals(changed,db.all().single())
        }} finally {context.deleteDatabase(name)}
    }

}
