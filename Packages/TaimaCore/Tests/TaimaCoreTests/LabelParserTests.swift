import Foundation
import Testing
@testable import TaimaCore

private func day(_ text: String) -> Date {
    LabelParser.dates(in: text).first!
}

private func parse(_ fixture: (lines: [RecognizedLine], codes: [DetectedCode])) -> LabelReading {
    LabelParser.parse(lines: fixture.lines, codes: fixture.codes)
}

@Suite("Label parser on captured labels")
struct LabelParserTests {
    @Test func girlScoutCookie() {
        let reading = parse(Fixtures.girlScoutCookie)
        #expect(reading.name == "Girl Scout Cookie")
        #expect(reading.thc == Potency(percent: 24))
        #expect(reading.cbd == Potency(percent: 1, isUpperBound: true))
        #expect(reading.grams == 5)
        #expect(reading.harvestedOn == day("02-07-2026"))
        #expect(reading.packedOn == day("28-09-2026"))
        // The QR payload wins over the misread printed text.
        #expect(reading.productID == "prd-00000000-0000-4000-8000-000000000110")
    }

    @Test func columnLayoutPairsLabelsWithValues() {
        let reading = parse(Fixtures.caliMix)
        #expect(reading.name == "Cali Mix")
        #expect(reading.thc == Potency(percent: 24))
        #expect(reading.cbd == Potency(percent: 1, isUpperBound: true))
        #expect(reading.grams == 5)
        #expect(reading.harvestedOn == day("28-07-2026"))
        #expect(reading.packedOn == day("12-10-2026"))
        #expect(reading.sku == "LB-CALIMIX-05")
        #expect(reading.producerKeys.contains("sku:LB"))
    }

    @Test func weightInTitleAndSKUWeightIgnored() {
        let reading = parse(Fixtures.phenoHunt)
        #expect(reading.name?.hasPrefix("Pheno Hunt") == true)
        #expect(reading.grams == 5)
        #expect(reading.thc != nil)
        #expect(reading.packedOn == day("14-09-2026"))
        #expect(reading.sku == "PHMX-FLW-50G")
    }

    @Test func twoLineTitleAndUnlabelledDates() {
        let reading = parse(Fixtures.motorbreath)
        #expect(reading.name == "R&D Exclusive Motorbreath")
        #expect(reading.grams == 1)
        #expect(reading.harvestedOn == day("12-05-2026"))
        #expect(reading.packedOn == day("23-09-2026"))
        #expect(reading.producerKeys.contains("tel:181729131"))
    }

    @Test func strainTypeFromName() {
        let reading = parse(Fixtures.selectionIndica)
        #expect(reading.name == "COG Selection Indica")
        #expect(reading.strainType == .indica)
        #expect(reading.ean == "8721098003880")
        #expect(reading.producerKeys.contains("ean:8721098"))
        #expect(reading.packedOn == day("28-09-2026"))
    }

    @Test func spacedLettersCollapse() {
        let reading = parse(Fixtures.amnesiaHaze)
        #expect(reading.name?.hasSuffix("Amnesia Haze Master Cut") == true)
        #expect(reading.thc == Potency(percent: 24))
        #expect(reading.producerKeys.contains("tel:181729131"))
    }

    @Test func producerAndLeaflet() {
        let reading = parse(Fixtures.whiteWidow)
        #expect(reading.name == "BIO Sunkissed White Widow")
        #expect(reading.producer == "Aardachtig Organics")
        #expect(reading.grams == 5)
        #expect(reading.thc == Potency(percent: 20))
        #expect(reading.harvestedOn == day("21-05-2026"))
        #expect(reading.packedOn == day("07-07-2026"))
        #expect(reading.leafletURL?.hasPrefix("https://open.overheid.nl") == true)
        #expect(reading.producerKeys.contains("domain:aardachtig.nl"))
    }

    @Test func handTrim() {
        let reading = parse(Fixtures.amnesiaS5)
        #expect(reading.name == "Amnesia S5 - Hand Trim")
        #expect(reading.thc == Potency(percent: 28))
        #expect(reading.grams == 1)
        #expect(reading.harvestedOn == day("22-07-2026"))
        #expect(reading.packedOn == day("08-09-2026"))
    }

    @Test func sameRowDates() {
        let reading = parse(Fixtures.speakSpecial)
        #expect(reading.name == "Speak Special")
        #expect(reading.thc == Potency(percent: 26))
        #expect(reading.grams == 2.5)
        #expect(reading.harvestedOn == day("27-03-2026"))
        #expect(reading.packedOn == day("28-08-2026"))
    }

    @Test func rejectsImpossibleDates() {
        #expect(LabelParser.dates(in: "31-02-2026").isEmpty)
        #expect(LabelParser.dates(in: "12-13-2026").isEmpty)
    }
}

@Test func expandingLowercaseDoesNotCrash() {
    let reading = LabelParser.parse(lines: [RecognizedLine("İİ geoogst 01-02-2026", x: 0.2, y: 0.5, width: 0.3, height: 0.03)], codes: [])
    #expect(reading.harvestedOn == LabelParser.dates(in: "01-02-2026").first)
}
