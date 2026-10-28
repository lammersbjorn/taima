package nl.taima.core

import java.security.MessageDigest

object Catalog {
    fun verify(manifest: String, files: Map<String, ByteArray>, build: Int): Boolean = runCatching {
        val root = Records.parse(manifest)
        require((root.number("minimumBuild") ?: 0.0) <= build)
        val entries = root.getAsJsonArray("files"); require(entries.size() > 0)
        entries.forEach { entry ->
            val file = entry.asJsonObject; val name = file.text("name")
            require(name.isNotEmpty() && !name.startsWith('.') && !name.contains('/') && !name.contains('\\') && name.endsWith(".json"))
            val bytes = requireNotNull(files[name]); require(bytes.size == file["size"].asInt)
            require(MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) } == file.text("sha256").lowercase())
        }
        true
    }.getOrDefault(false)
}
