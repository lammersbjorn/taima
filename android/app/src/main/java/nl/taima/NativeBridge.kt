package nl.taima

/** Small stable byte-array ABI; Swift errors use explicit JSON envelopes. */
object NativeBridge {
    external fun call(json: ByteArray): ByteArray
    external fun normalize(json: ByteArray): ByteArray
    external fun coreBatch(json: ByteArray, iterations: Int): Double
    fun load() { System.loadLibrary("taimajni") }
}
