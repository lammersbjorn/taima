import Foundation
import Testing
@testable import TaimaCore

private func day(_ text: String) -> Date { LabelParser.dates(in: text).first! }

@Suite("Published experiment labels")
struct WebLabelTests {
    @Test func fytaValueBeforeLabel() {
        let reading = LabelParser.parse(lines: WebFixtures.fytaSourDelight.lines, codes: WebFixtures.fytaSourDelight.codes)
        #expect(reading.name == "Sour Delight")
        #expect(reading.thc == Potency(percent: 20))
        #expect(reading.cbd == Potency(percent: 1, isUpperBound: true))
        #expect(reading.grams == 1)
        #expect(reading.harvestedOn == day("20-05-2024"))
        #expect(reading.packedOn == day("12-12-2024"))
        #expect(reading.producer == "FYTA")
        #expect(reading.productID == "prd-00000000-0000-4000-8000-000000000106")
    }

    @Test func garbledDateLabels() {
        let reading = LabelParser.parse(lines: WebFixtures.aardachtigJar.lines, codes: [])
        #expect(reading.name == "Bio Gmo x Zki")
        #expect(reading.producer == "Aardachtig Organics")
        #expect(reading.harvestedOn == day("17-05-2024"))
        #expect(reading.packedOn == day("28-10-2024"))
    }

    @Test func producedDateAndPrintedProductID() {
        let reading = LabelParser.parse(lines: WebFixtures.holiFresh.lines, codes: WebFixtures.holiFresh.codes)
        #expect(reading.name == "Holi Fresh")
        #expect(reading.grams == 0.5)
        #expect(reading.harvestedOn == day("13-01-2026"))
        #expect(reading.packedOn == day("22-05-2026"))
        #expect(reading.productID == "prd-00000000-0000-4000-8000-000000000113")
        #expect(reading.producer == "Holigram")
    }

    @Test func cogIsCanadelaar() {
        #expect(GrowerDirectory.match(keys: [], text: "C O G Golden Joint Edition 1") == "Canadelaar")
        #expect(GrowerDirectory.match(keys: [], text: "Cognac notes") == nil)
    }
}

@Test func zunamiLabel() {
    // Vision output from the owner's Zunami (Linsboer) bag, 2026-10-27.
    let lines = WebFixtures.zunami.lines
    let codes = WebFixtures.zunami.codes
    let reading = LabelParser.parse(lines: lines, codes: codes)
    #expect(reading.name == "Zunami")
    #expect(reading.grams == 1)
    #expect(reading.thc == Potency(percent: 24))
    #expect(reading.cbd == Potency(percent: 1, isUpperBound: true))
    #expect(reading.harvestedOn == LabelParser.dates(in: "25-08-2026").first)
    #expect(reading.packedOn == LabelParser.dates(in: "14-10-2026").first)
    #expect(reading.productID == "prd-00000000-0000-4000-8000-000000000102")
    #expect(reading.sku == "ZUNA-FLW-10G")
}
