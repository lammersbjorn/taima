package nl.taima.core

import com.google.gson.JsonObject
import java.io.*
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec

/** Format 2, same UTF-8 passphrase / PBKDF2-SHA256 / AES-256-GCM as TaimaCore. */
object Archive {
    private val magic = "TAIMABK2".toByteArray(Charsets.US_ASCII)
    data class Backup(val manifest: JsonObject, val photos: Map<String, ByteArray>)
    fun key(passphrase: String, salt: ByteArray, rounds: Int): ByteArray {
        require(rounds in 1..2_000_000) { "Invalid iteration count" }
        val spec = PBEKeySpec(passphrase.toCharArray(), salt, rounds, 256)
        return try { SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).encoded } finally { spec.clearPassword() }
    }
    fun safePhoto(name: String) = name.isNotEmpty() && !name.startsWith('.') && !name.contains('/') && !name.contains('\\') && name.endsWith(".heic")
    fun write(output: OutputStream, backup: Backup, passphrase: String?, random: SecureRandom = SecureRandom()) {
        val encrypted = !passphrase.isNullOrEmpty()
        val stream = DataOutputStream(output)
        stream.write(magic); stream.writeByte(if (encrypted) 1 else 0)
        val key = if (encrypted) {
            val salt = ByteArray(16).also(random::nextBytes); stream.write(salt); stream.writeInt(210_000)
            key(passphrase!!, salt, 210_000)
        } else null
        fun record(kind: Int, name: String, body: ByteArray) {
            val bytes = name.toByteArray(Charsets.UTF_8)
            require(bytes.size <= 65535)
            var payload = ByteArrayOutputStream().also { out -> DataOutputStream(out).apply { writeByte(kind); writeShort(bytes.size); write(bytes); write(body) } }.toByteArray()
            if (key != null) {
                val nonce = ByteArray(12).also(random::nextBytes)
                val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                cipher.init(Cipher.ENCRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(128, nonce))
                payload = nonce + cipher.doFinal(payload)
            }
            stream.writeInt(payload.size); stream.write(payload)
        }
        record(1, "manifest.json", Records.canonical(backup.manifest).toByteArray(Charsets.UTF_8))
        backup.photos.toSortedMap().forEach { (name, bytes) -> require(safePhoto(name)); record(2, name, bytes) }
        stream.flush()
    }
    fun read(input: InputStream, passphrase: String?): Backup {
        val stream = DataInputStream(input)
        fun bytes(n: Int) = ByteArray(n).also(stream::readFully)
        require(bytes(8).contentEquals(magic)) { "Not a Taima backup" }
        val mode = stream.readUnsignedByte(); require(mode in 0..1) { "Unknown backup mode" }
        val key = if (mode == 1) {
            val salt = bytes(16); val rounds = stream.readInt()
            require(!passphrase.isNullOrEmpty()) { "Passphrase required" }; key(passphrase, salt, rounds)
        } else null
        var manifest: JsonObject? = null
        val photos = linkedMapOf<String, ByteArray>()
        var total = 0L
        while (true) {
            val first = stream.read(); if (first == -1) break
            val size = (first shl 24) or (stream.readUnsignedByte() shl 16) or (stream.readUnsignedByte() shl 8) or stream.readUnsignedByte()
            require(size in 3..32 * 1024 * 1024) { "Invalid record size" }
            total += size; require(total <= 256L * 1024 * 1024) { "Backup exceeds trial limit" }
            var payload = bytes(size)
            if (key != null) {
                require(payload.size >= 28)
                val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                cipher.init(Cipher.DECRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(128, payload.copyOfRange(0, 12)))
                payload = cipher.doFinal(payload.copyOfRange(12, payload.size))
            }
            val record = DataInputStream(ByteArrayInputStream(payload)); val kind = record.readUnsignedByte()
            val name = ByteArray(record.readUnsignedShort()).also(record::readFully).toString(Charsets.UTF_8)
            val body = record.readBytes()
            when (kind) {
                1 -> { require(manifest == null && name == "manifest.json"); manifest = Records.parse(body.toString(Charsets.UTF_8)); require(manifest.get("version").asInt == 2) { "Unsupported backup version" } }
                2 -> { require(manifest != null && safePhoto(name) && !photos.containsKey(name)); photos[name] = body }
            }
        }
        val result = requireNotNull(manifest) { "Missing manifest" }
        result.getAsJsonArray("bags").forEach { Records.validate(it.asJsonObject, requireName = false) }
        return Backup(result, photos)
    }
}
