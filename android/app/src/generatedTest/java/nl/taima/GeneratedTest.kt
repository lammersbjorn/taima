package nl.taima
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.ext.junit.runners.AndroidJUnit4
import nl.taima.generated.TaimaGenerated
import org.junit.Test
import org.junit.Assert.*
import org.junit.runner.RunWith
import kotlin.system.measureNanoTime
@RunWith(AndroidJUnit4::class)
class GeneratedTest {
    @Test fun generatedAgainstHandwritten() {
        val bytes=InstrumentationRegistry.getInstrumentation().context.assets.open("record.json").use {it.readBytes()}
        val input=bytes.toString(Charsets.UTF_8)
        NativeBridge.load()
        assertEquals(NativeBridge.normalize(bytes).toString(Charsets.UTF_8),TaimaGenerated.normalizeBagJSON(input))
        assertEquals("{\"error\":\"invalidJSON\"}",TaimaGenerated.normalizeBagJSON("{"))
        assertEquals("{\"error\":\"invalidRecord\"}",TaimaGenerated.normalizeBagJSON(input.replace("\"grams\":5.5","\"grams\":-1")))
        // Both paths get the same UTF-16 input and return UTF-16 output in this comparison.
        var checksum=0
        repeat(1000) {TaimaGenerated.normalizeBagJSON(input)}
        val generated=List(7) {measureNanoTime {repeat(10000) {checksum+=TaimaGenerated.normalizeBagJSON(input).length}}/10000.0}.sorted()
        repeat(1000) {NativeBridge.normalize(input.toByteArray()).toString(Charsets.UTF_8)}
        val manual=List(7) {measureNanoTime {repeat(10000) {checksum+=NativeBridge.normalize(input.toByteArray()).toString(Charsets.UTF_8).length}}/10000.0}.sorted()
        println("TAIMA_GENERATED generated_ns=$generated handwritten_string_ns=$manual checksum=$checksum bytes=${bytes.size}")
    }
}
