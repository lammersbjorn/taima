import Foundation
import Testing
@testable import TaimaCore

@Suite struct LabelFusionTests {
    func reading(name: String? = nil, thc: Double? = nil, grams: Double? = nil, packed: String? = nil, id: String? = nil, keys: [String] = [], text: String = "") -> LabelReading {
        var reading = LabelReading()
        reading.name = name
        reading.thc = thc.map { Potency(percent: $0) }
        reading.grams = grams
        reading.packedOn = packed.flatMap { LabelParser.dates(in: $0).first }
        reading.productID = id
        reading.producerKeys = keys
        reading.text = text
        return reading
    }

    @Test func eachFrameAddsWhatItSees() {
        var fusion = LabelFusion()
        fusion.add(reading(name: "Golden Joint", text: "Golden Joint"))
        #expect(fusion.coverage == 0.2)
        fusion.add(reading(thc: 22, grams: 1.5, text: "THC 22%\n3 x 0,5 g"))
        fusion.add(reading(packed: "12-10-2026", id: "prd-1", keys: ["tel:181729131"], text: "Verpakt 12-10-2026"))
        #expect(fusion.isComplete)
        let result = fusion.reading
        #expect(result.name == "Golden Joint" && result.thc?.percent == 22 && result.grams == 1.5)
        #expect(result.producerKeys == ["tel:181729131"])
        #expect(result.text.split(separator: "\n").count == 4)
    }

    @Test func majorityBeatsAMisread() {
        var fusion = LabelFusion()
        for _ in 0..<4 { fusion.add(reading(thc: 26)) }
        fusion.add(reading(thc: 25))
        #expect(fusion.reading.thc?.percent == 26)
    }

    @Test func tiesPreferTheFullerName() {
        var fusion = LabelFusion()
        fusion.add(reading(name: "Golden Jo"))
        fusion.add(reading(name: "Golden Joint Edition 1"))
        #expect(fusion.reading.name == "Golden Joint Edition 1")
    }

    @Test func emptyFusionIsEmpty() {
        let fusion = LabelFusion()
        #expect(fusion.reading.detectedFields.isEmpty)
        #expect(fusion.coverage == 0)
    }
}
