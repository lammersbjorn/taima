package nl.taima.core

import org.junit.Assert.*
import org.junit.Test
import java.io.*
import java.security.SecureRandom
import java.time.*
import java.util.Locale
import java.util.TimeZone

class ContractTest {
    private val root = File(System.getProperty("taima.goldens"))
    private fun bytes(name: String) = File(root, name).readBytes()
    private fun text(name: String) = bytes(name).toString(Charsets.UTF_8)
    private fun fixture() = Records.parse(text("record.json"))
    @Test fun recordBytes() { val bag = fixture(); Records.validate(bag); assertEquals(text("record.json"), Records.canonical(bag)) }
    @Test fun backupBothWaysAndCryptoBytes() {
        val expected = text("manifest.json")
        val fixed = object : SecureRandom() { var next = 0; override fun nextBytes(bytes: ByteArray) { bytes.indices.forEach { bytes[it] = next++.toByte() } } }
        assertEquals(text("pbkdf2.hex"), Archive.key("taima-é-🌿", ByteArray(16) { it.toByte() }, 210_000).joinToString("") { "%02x".format(it) })
        for ((name, passphrase) in listOf("plain.taimabackup" to null, "encrypted.taimabackup" to "taima-é-🌿")) {
            val backup = Archive.read(ByteArrayInputStream(bytes(name)), passphrase)
            assertEquals(expected, Records.canonical(backup.manifest))
            val out = ByteArrayOutputStream(); Archive.write(out, backup, passphrase, fixed)
            assertArrayEquals(bytes(name), out.toByteArray())
            assertEquals(expected, Records.canonical(Archive.read(ByteArrayInputStream(out.toByteArray()), passphrase).manifest))
        }
        assertThrows(Exception::class.java) { Archive.read(ByteArrayInputStream(bytes("encrypted.taimabackup")), "wrong") }
        val corrupted = bytes("encrypted.taimabackup").also { it[it.lastIndex] = (it.last().toInt() xor 1).toByte() }
        assertThrows(Exception::class.java) { Archive.read(ByteArrayInputStream(corrupted), "taima-é-🌿") }
    }
    @Test fun photosAndArchiveValidation() {
        Records.validate(fixture().apply { addProperty("name", "") }, requireName = false)
        val photo = "00000000-0000-4000-8000-000000000003.heic"
        val out = ByteArrayOutputStream()
        Archive.write(out, Archive.Backup(Records.parse(text("manifest.json")), mapOf(photo to byteArrayOf(1,2,3))), "local")
        assertArrayEquals(byteArrayOf(1,2,3), Archive.read(ByteArrayInputStream(out.toByteArray()), "local").photos[photo])
        for (name in listOf("../escape.heic", "/a.heic", "a\\b.heic", ".heic", "a.jpg")) assertFalse(Archive.safePhoto(name))
        assertThrows(Exception::class.java) { Archive.read(ByteArrayInputStream(bytes("plain.taimabackup").copyOf(30)), null) }
    }
    @Test fun csvAndNumbersAcrossLocales() {
        val previous = Locale.getDefault(); val zone = TimeZone.getDefault()
        try {
            TimeZone.setDefault(TimeZone.getTimeZone("Europe/Amsterdam"))
            for (tag in listOf("nl-NL", "de-DE", "en-US")) {
                val locale = Locale.forLanguageTag(tag); Locale.setDefault(locale)
                assertEquals(tag, text("collection.csv"), CSV.make(listOf(fixture())))
                val imported = CSV.parse(text("collection.csv")).single()
                assertEquals(fixture().text("name"), imported.text("name")); assertEquals(5.5, imported.number("grams")!!, 0.0)
                assertEquals("empty", imported.text("stockState")); assertEquals(0, imported.getAsJsonArray("usageLog").size())
                val decimal = if (tag == "en-US") "1.5" else "1,5"
                assertEquals(1.5, AmountInput.parse(decimal, locale)!!, 0.0)
                assertNull(AmountInput.parse("1,000.5", locale)); assertNull(AmountInput.parse("1.000,5", locale))
                assertNull(AmountInput.parse(if(tag == "en-US") "1,5" else "1.5", locale))
                for (value in listOf("1.5", "1,5")) assertEquals(1.5, CSV.parse("name;grams\nExample;$value\n").single().number("grams")!!, 0.0)
                println("PASS locale=$tag CSV bytes=${bytes("collection.csv").size} decimal=$decimal")
            }
        } finally { Locale.setDefault(previous); TimeZone.setDefault(zone) }
    }
    @Test fun amsterdamDST() {
        val before = Instant.parse("2026-03-28T11:00:00Z").atZone(ZoneId.of("Europe/Amsterdam"))
        val after = before.plusDays(1)
        assertEquals(23, Duration.between(before,after).toHours()); assertEquals(12, after.hour)
    }
    @Test fun catalogDigestAndPaths() {
        assertTrue(Catalog.verify(text("catalog-manifest.json"), mapOf("catalog.json" to bytes("catalog.json")), 1))
        assertFalse(Catalog.verify(text("catalog-manifest.json"), mapOf("catalog.json" to byteArrayOf(1)), 1))
        assertFalse(Catalog.verify(text("catalog-manifest.json"), mapOf("catalog.json" to bytes("catalog.json")), 0))
        assertFalse(Catalog.verify(text("catalog-manifest.json").replace("catalog.json","../catalog.json"), mapOf("../catalog.json" to bytes("catalog.json")), 1))
    }
    @Test fun editAndSessionPreserveUnknownFields() {
        val bag = fixture().apply { addProperty("futureField", "keep me") }
        val logged = Records.log(bag, 0.25, "vape", "Synthetic")
        assertEquals("keep me", logged.text("futureField")); assertEquals(5.0, Records.remaining(logged),0.0)
        assertThrows(IllegalArgumentException::class.java) { Records.log(bag, 10.0, "vape", "") }
        assertEquals("{\"error\":\"invalidJSON\"}", Records.normalize("{"))
    }
}
