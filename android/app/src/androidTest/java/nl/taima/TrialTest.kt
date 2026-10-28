package nl.taima

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import androidx.room.Room
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.ext.junit.runners.AndroidJUnit4
import nl.taima.core.*
import nl.taima.room.*
import org.junit.*
import org.junit.Assert.*
import org.junit.runner.RunWith
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.util.Locale
import kotlin.system.measureNanoTime

@RunWith(AndroidJUnit4::class)
class TrialTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context: Context get() = instrumentation.targetContext
    private fun bytes(name:String)=instrumentation.context.assets.open(name).use { it.readBytes() }
    private fun fixture()=Records.parse(bytes("record.json").toString(Charsets.UTF_8))
    @Test fun contractOnART() {
        for((name,pass) in listOf("plain.taimabackup" to null,"encrypted.taimabackup" to "taima-é-🌿")) {
            val backup=Archive.read(ByteArrayInputStream(bytes(name)),pass)
            assertEquals(Records.canonical(fixture()),Records.canonical(backup.manifest.getAsJsonArray("bags")[0]))
            val out=ByteArrayOutputStream();Archive.write(out,backup,pass)
            assertEquals(backup.manifest,Archive.read(ByteArrayInputStream(out.toByteArray()),pass).manifest)
        }
        assertTrue(Catalog.verify(bytes("catalog-manifest.json").toString(Charsets.UTF_8),mapOf("catalog.json" to bytes("catalog.json")),1))
        val old=Locale.getDefault()
        try { for(tag in listOf("nl-NL","de-DE","en-US")) { Locale.setDefault(Locale.forLanguageTag(tag));assertArrayEquals(bytes("collection.csv"),CSV.make(listOf(fixture())).toByteArray()) } } finally {Locale.setDefault(old)}
    }
    private fun v1(name:String) {
        context.deleteDatabase(name)
        SQLiteDatabase.openOrCreateDatabase(context.getDatabasePath(name),null).use { db ->
            db.execSQL("CREATE TABLE bag (id TEXT PRIMARY KEY NOT NULL, collected_on REAL NOT NULL, body TEXT NOT NULL)")
            db.execSQL("CREATE INDEX bag_collected ON bag (collected_on DESC)")
            db.execSQL("CREATE TABLE producer_key (key TEXT PRIMARY KEY NOT NULL, producer TEXT NOT NULL)")
            db.execSQL("INSERT INTO bag VALUES(?,?,?)",arrayOf<Any>(fixture().text("id"),1.0,Records.canonical(fixture())))
            db.version=1
        }
    }
    @Test fun migrationsAndStorageBenchmark() {
        val plainName="trial-plain.db";val roomName="trial-room.db"
        try {
            v1(plainName);v1(roomName)
            BagDatabase(context,plainName).use { db -> assertEquals(fixture(),db.all().single());db.readableDatabase.rawQuery("SELECT * FROM wishlist",null).use { assertEquals(0,it.count) } }
            Room.databaseBuilder(context,TrialRoom::class.java,roomName).addMigrations(TrialRoom.V1_V2).build().using { db -> assertEquals(1,db.bags().all().size) }
            context.deleteDatabase(plainName);context.deleteDatabase(roomName)
            val bodies=List(1000) { i -> Records.canonical(fixture().apply { addProperty("id", "00000000-0000-4000-8000-${i.toString().padStart(12,'0')}") }) }
            BagDatabase(context,plainName).use { plain ->
                Room.databaseBuilder(context,TrialRoom::class.java,roomName).setJournalMode(androidx.room.RoomDatabase.JournalMode.WRITE_AHEAD_LOGGING).build().using { room ->
                    plain.writableDatabase;room.openHelper.writableDatabase
                    fun plainBatch() { val db=plain.writableDatabase;db.beginTransaction();try {repeat(1000) { db.execSQL("INSERT OR REPLACE INTO bag(id,collected_on,body) VALUES(?,?,?)",arrayOf<Any>("00000000-0000-4000-8000-${it.toString().padStart(12,'0')}",it.toDouble(),bodies[it])) };db.setTransactionSuccessful()} finally{db.endTransaction()} }
                    fun roomBatch() { room.runInTransaction { repeat(1000) { i -> room.bags().put(BagRow().apply { id="00000000-0000-4000-8000-${i.toString().padStart(12,'0')}";collectedOn=i.toDouble();this.body=bodies[i] }) } } }
                    plainBatch();roomBatch()
                    val a=List(7) { measureNanoTime { plainBatch() } / 1e6 }.sorted()
                    val b=List(7) { measureNanoTime { roomBatch() } / 1e6 }.sorted()
                    assertEquals(1000,room.bags().all().size)
                    assertEquals(1000,plain.readableDatabase.rawQuery("SELECT body FROM bag",null).use{it.count})
                    println("TAIMA_STORAGE plain_ms=$a room_ms=$b median_plain=${a[3]} median_room=${b[3]} rows=1000 WAL=true transaction=true")
                }
            }
        } finally { context.deleteDatabase(plainName);context.deleteDatabase(roomName) }
    }
    @Test fun restoreIsAtomicAndPreservesPhotos() {
        val name="trial-restore.db";context.deleteDatabase(name)
        try { BagDatabase(context,name).use { db ->
            db.put(fixture()); val backup=Archive.read(ByteArrayInputStream(bytes("plain.taimabackup")),null)
            val photo="00000000-0000-4000-8000-000000000003.heic"
            db.restoreBackup(backup.manifest,mapOf(photo to byteArrayOf(1,2,3)))
            assertArrayEquals(byteArrayOf(1,2,3),db.photos()[photo]);assertEquals(fixture(),db.all().single())
            assertThrows(Exception::class.java) { db.restoreBackup(backup.manifest,mapOf("../bad.heic" to byteArrayOf(0))) }
            assertArrayEquals(byteArrayOf(1,2,3),db.photos()[photo]);assertEquals(fixture(),db.all().single())
        } } finally {context.deleteDatabase(name)}
    }
    @Test fun bridgeBenchmark() {
        Assume.assumeTrue("Optional native probe not packaged",runCatching { NativeBridge.load() }.isSuccess)
        val input=bytes("record.json");val expected="{\"record\":"+input.toString(Charsets.UTF_8)+"}"
        assertEquals(expected,NativeBridge.normalize(input).toString(Charsets.UTF_8))
        assertEquals("{\"error\":\"invalidJSON\"}",NativeBridge.normalize("{".toByteArray()).toString(Charsets.UTF_8))
        val invalid=fixture().apply { addProperty("grams",-1) }
        assertEquals("{\"error\":\"invalidRecord\"}",NativeBridge.normalize(Records.canonical(invalid).toByteArray()).toString(Charsets.UTF_8))
        repeat(1000) { NativeBridge.normalize(input) }
        var checksum=0
        val native=List(7) { measureNanoTime { repeat(10000) { checksum+=NativeBridge.normalize(input).size } } / 10000.0 }.sorted()
        val text=input.toString(Charsets.UTF_8);repeat(1000) {Records.normalize(text)}
        val kotlin=List(7) { measureNanoTime {repeat(10000) {checksum+=Records.normalize(text).length}} / 10000.0 }.sorted()
        val direct=List(7) { NativeBridge.coreBatch(input,10000) }.sorted()
        println("TAIMA_BRIDGE handwritten_ns=$native kotlin_ns=$kotlin swift_direct_ns=$direct checksum=$checksum bytes=${input.size}")
    }
}

private inline fun <T: androidx.room.RoomDatabase,R> T.using(block: (T)->R):R = try { block(this) } finally { close() }
