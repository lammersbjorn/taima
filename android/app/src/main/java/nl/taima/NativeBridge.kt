package nl.taima

/** Optional measurement build only; the shipping trial uses the Kotlin contracts. */
object NativeBridge {
    external fun normalize(json: ByteArray): ByteArray
    external fun coreBatch(json: ByteArray, iterations: Int): Double
    fun load() { System.loadLibrary("taimajni") }
}
