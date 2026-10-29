package nl.taima

import android.content.Context
import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import com.google.gson.*

import java.time.Instant

/** BagStore's explicit tables. body is JSON, timestamps use Apple's reference epoch. */
class BagDatabase(context: Context, name: String = "taima.db") : SQLiteOpenHelper(context, name, null, 2) {
    init { setWriteAheadLoggingEnabled(true) }
    override fun onConfigure(db: SQLiteDatabase) { db.setForeignKeyConstraintsEnabled(true) }
    override fun onCreate(db: SQLiteDatabase) { migrate(db, 0) }
    override fun onOpen(db: SQLiteDatabase) { super.onOpen(db); db.execSQL("CREATE TABLE IF NOT EXISTS android_photo (name TEXT PRIMARY KEY NOT NULL, body BLOB NOT NULL)") }
    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) { migrate(db, oldVersion) }
    private fun migrate(db: SQLiteDatabase, old: Int) {
        if (old < 1) {
            db.execSQL("CREATE TABLE IF NOT EXISTS bag (id TEXT PRIMARY KEY NOT NULL, collected_on REAL NOT NULL, body TEXT NOT NULL)")
            db.execSQL("CREATE INDEX IF NOT EXISTS bag_collected ON bag (collected_on DESC)")
            db.execSQL("CREATE TABLE IF NOT EXISTS producer_key (key TEXT PRIMARY KEY NOT NULL, producer TEXT NOT NULL)")
        }
        if (old < 2) db.execSQL("CREATE TABLE IF NOT EXISTS wishlist (key TEXT PRIMARY KEY NOT NULL, name TEXT NOT NULL, added_at REAL NOT NULL)")
    }
    fun transaction(block: ()->Unit) {
        val db=writableDatabase;db.beginTransaction();try {block();db.setTransactionSuccessful()} finally {db.endTransaction()}
    }
    fun mutate(id: String, change: (JsonObject)->JsonObject) {
        val db=writableDatabase;db.beginTransaction()
        try { val bag=all().first {it.text("id")==id};put(db,change(bag));prunePhotos();db.setTransactionSuccessful() } finally {db.endTransaction()}
    }
    fun delete(id: String) { transaction {writableDatabase.delete("bag", "id=?", arrayOf(id));prunePhotos()} }
    private fun prunePhotos() {
        val retained=all().flatMap {bag ->buildList {
            listOf("photoName","backPhotoName").forEach {key ->bag.text(key).takeIf(String::isNotBlank)?.let {add(it)}}
            addAll(bag.array("extraPhotoNames").map {it.asString})
            bag.array("timedNotes").forEach {note ->note.asJsonObject.text("photoName").takeIf(String::isNotBlank)?.let {add(it)}}
        }}.toSet()
        val names=readableDatabase.rawQuery("SELECT name FROM android_photo",null).use {rows ->buildList {while(rows.moveToNext()) add(rows.getString(0))}}
        names.filterNot {it in retained}.forEach {writableDatabase.delete("android_photo","name=?",arrayOf(it))}
    }
    fun putPhoto(name: String, bytes: ByteArray) { writableDatabase.insertOrThrow("android_photo", null, ContentValues().apply { put("name", name); put("body", bytes) }) }
    fun toggleWish(key: String, name: String) {
        if (writableDatabase.delete("wishlist", "key=?", arrayOf(key)) == 0) writableDatabase.execSQL("INSERT INTO wishlist(key,name,added_at) VALUES(?,?,?)", arrayOf(key, name, Instant.now().epochSecond - 978307200.0))
    }
    fun all(): List<JsonObject> = readableDatabase.rawQuery("SELECT body FROM bag ORDER BY collected_on DESC", null).use { rows ->
        buildList { while (rows.moveToNext()) add(JsonParser.parseString(rows.getString(0)).asJsonObject) }
    }
    fun put(bag: JsonObject) { transaction {put(writableDatabase, bag);prunePhotos()} }
    private fun put(db: SQLiteDatabase, bag: JsonObject) {
        val timestamp = Instant.parse(bag.text("collectedOn"))
        db.insertWithOnConflict("bag", null, ContentValues().apply {
            put("id", bag.text("id")); put("collected_on", timestamp.epochSecond.toDouble() + timestamp.nano / 1e9 - 978307200.0); put("body", bag.toString())
        }, SQLiteDatabase.CONFLICT_REPLACE).also { check(it != -1L) }
    }
    fun snapshot(): JsonObject = JsonObject().apply {
        addProperty("version", 2); addProperty("exportedAt", timestamp())
        add("bags", JsonArray().also { array -> all().forEach(array::add) })
        add("wishlist", JsonArray().also { array -> readableDatabase.rawQuery("SELECT key,name,added_at FROM wishlist ORDER BY key",null).use { c -> while(c.moveToNext()) array.add(JsonObject().apply { addProperty("key",c.getString(0)); addProperty("name",c.getString(1)); addProperty("addedAt",Instant.ofEpochMilli(((c.getDouble(2)+978307200)*1000).toLong()).toString()) }) } })
        add("producerKeys", JsonObject().also { keys -> readableDatabase.rawQuery("SELECT key,producer FROM producer_key ORDER BY key", null).use { c -> while(c.moveToNext()) keys.addProperty(c.getString(0),c.getString(1)) } })
    }
    fun photo(name: String): ByteArray? = readableDatabase.rawQuery("SELECT body FROM android_photo WHERE name=?",arrayOf(name)).use {if(it.moveToFirst()) it.getBlob(0) else null}
    fun exportPhotos(folder: java.io.File) {
        readableDatabase.rawQuery("SELECT name,body FROM android_photo",null).use {rows ->while(rows.moveToNext()) {
            val name=rows.getString(0);require(java.io.File(name).name==name);java.io.File(folder,name).writeBytes(rows.getBlob(1))
        }}
    }
    fun restoreDirectory(manifest: JsonObject, folder: java.io.File) {
        transaction {
            restore(manifest);writableDatabase.delete("android_photo",null,null)
            folder.listFiles().orEmpty().forEach {file ->require(file.name.matches(Regex("[A-Za-z0-9_-]+\\.heic")));putPhoto(file.name,file.readBytes())}
        }
    }
    fun photos(): Map<String, ByteArray> = readableDatabase.rawQuery("SELECT name,body FROM android_photo",null).use { c -> buildMap { while(c.moveToNext()) put(c.getString(0),c.getBlob(1)) } }
    fun restoreBackup(manifest: JsonObject, photos: Map<String, ByteArray>) {
        val db=writableDatabase; db.beginTransaction()
        try {
            restore(manifest); db.delete("android_photo",null,null)
            photos.forEach { (name,body) -> require(name.matches(Regex("[A-Za-z0-9_-]+\\.heic")));db.insertOrThrow("android_photo",null,ContentValues().apply { put("name",name);put("body",body) }) }
            db.setTransactionSuccessful()
        } finally { db.endTransaction() }
    }
    fun importCSV(bags: List<JsonObject>) {
        require(bags.isNotEmpty())
        val db=writableDatabase;db.beginTransaction()
        try { bags.forEach { put(db,it) };db.setTransactionSuccessful() } finally { db.endTransaction() }
    }
    /** Whole restore is one transaction. Validate before touching existing rows. */
    fun restore(manifest: JsonObject) {
        val bags = manifest.getAsJsonArray("bags").map { it.asJsonObject }
        val db = writableDatabase; db.beginTransaction()
        try {
            db.delete("bag",null,null); db.delete("wishlist",null,null); db.delete("producer_key",null,null)
            bags.forEach { put(db,it) }
            manifest.getAsJsonArray("wishlist")?.forEach { value -> val wish = value.asJsonObject
                db.execSQL("INSERT INTO wishlist(key,name,added_at) VALUES(?,?,?)", arrayOf<Any>(wish.text("key"),wish.text("name"), Instant.parse(wish.text("addedAt")).epochSecond.toDouble()-978307200))
            }
            manifest.getAsJsonObject("producerKeys")?.entrySet()?.forEach { (key, producer) -> db.execSQL("INSERT INTO producer_key(key,producer) VALUES(?,?)", arrayOf(key, producer.asString)) }
            db.setTransactionSuccessful()
        } finally { db.endTransaction() }
    }
}
