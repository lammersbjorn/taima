import Foundation
import Testing
@testable import TaimaCore

@Suite struct LabelFormatTests {
    func parse(_ texts: [String]) -> LabelReading {
        LabelParser.parse(lines: texts.enumerated().map { index, text in
            RecognizedLine(text, x: 0.15, y: 0.8 - Double(index) * 0.06, width: 0.6, height: 0.03, confidence: 0.95)
        }, codes: [])
    }

    @Test(arguments: ["THC 22-26%", "THC 22,0–26,0%", "22-26% THC", "thc-totaal: 22-26%"])
    func potencyRanges(_ text: String) {
        let value = parse([text]).thc
        #expect(value?.percent == 26 && value?.lowerBound == 22)
        #expect(value?.isUpperBound == false)
    }

    @Test(arguments: ["CBD <1%", "CBD ≤ 1%", "CBD ‹1%", "CBD «1%", "CBD 〈1%"])
    func upperBoundLookAlikes(_ text: String) {
        #expect(parse([text]).cbd == Potency(percent: 1, isUpperBound: true))
    }

    @Test func cannabinoidBasisIsPreserved() {
        let acid = parse(["THCA 23,5%"])
        #expect(acid.thc?.percent == 23.5 && acid.thc?.basis == .thca)
        #expect(acid.confidence[.thc]?.needsReview == true)
        let total = parse(["THCA 27%", "THC-totaal 24,5%"])
        #expect(total.thc?.basis == .totalTHC && total.thc?.percent == 24.5)
    }

    @Test(arguments: ["THC 26-22%", "THC <22-26%", "THC 125%", "THC 2,5.4%", "26,5% THCAFE"])
    func invalidPotenciesAreRejected(_ text: String) { #expect(parse([text]).thc == nil) }

    @Test(arguments: ["0,5g", "1.0 gram", "3 x 0,35 g", "2 stuks"])
    func weightsAndCounts(_ text: String) {
        let reading = parse([text])
        switch text {
        case "0,5g": #expect(reading.grams == 0.5)
        case "1.0 gram": #expect(reading.grams == 1)
        case "3 x 0,35 g": #expect(reading.grams == 1.05 && reading.unitCount == 3 && reading.form == .preroll)
        default: #expect(reading.grams == nil && reading.unitCount == 2 && reading.form == .preroll)
        }
    }

    @Test func explicitWeightWinsOverSKUAndStatusBar() {
        #expect(parse(["19:50 G", "Moon Garden 1g", "AB-FLW-0.5G"]).grams == 1)
        let skuOnly = parse(["AB-FLW-0.5G"])
        #expect(skuOnly.grams == 0.5 && skuOnly.confidence[.grams]?.source == .inferred)
        #expect(skuOnly.confidence[.grams]?.needsReview == true)
        #expect(parse(["PHMX-FLW-50G"]).grams == nil)
    }

    @Test(arguments: ["2026-10-12", "12 okt 2026", "12 okt. 2026", "12 oktober 2026", "12 OKTOBER 2026"])
    func dateFormats(_ text: String) {
        #expect(parse(["Verpakt " + text]).packedOn == LabelParser.dates(in: "12-10-2026").first)
    }

    @Test(arguments: ["2026-02-31", "31 februari 2026", "12 onbekend 2026", "2026-13-12", "2026-10-123"])
    func impossibleDatesAreRejected(_ text: String) { #expect(LabelParser.dates(in: text).isEmpty) }

    @Test func expiryCannotSupplyMissingPackDate() {
        let reading = parse(["Verpakt: THT 12-10-2027", "Houdbaar tot 01-10-2027 / 02-10-2027"])
        #expect(reading.packedOn == nil && reading.harvestedOn == nil)
        #expect(reading.bestBeforeOn == LabelParser.dates(in: "12-10-2027").first)
        #expect(reading.detectedFields.contains(.bestBeforeOn))
        let split = parse(["Houdbaar tot:", "12 okt 2027"])
        #expect(split.bestBeforeOn == LabelParser.dates(in: "12-10-2027").first)
        #expect(split.packedOn == nil)
    }

    @Test(arguments: ["Teler: Groene Vallei B.V.", "Groene Vallei B.V. | Teler", "Gekweekt door Groene Vallei B.V.", "Teler / producent: Groene Vallei B.V. | Tel: 123456789"])
    func growerLayouts(_ text: String) { #expect(parse([text]).producer == "Groene Vallei B.V") }

    @Test func standaloneGrowerHeadingDoesNotConsumeAField() {
        #expect(GrowerDirectory.labelledGrower(in: ["Teler:", "THC 24%", "Gewicht 5g"]) == nil)
        #expect(GrowerDirectory.labelledGrower(in: ["Geteeld door:", "Groene Vallei B.V."]) == "Groene Vallei B.V")
        #expect(parse(["Geteeld door:", "Groene Vallei", "Holigram"]).producer == "Groene Vallei")
    }

    @Test func centeredWrappedNameAndLargeBrand() {
        let reading = LabelParser.parse(lines: [
            RecognizedLine("COG", x: 0.3, y: 0.8, width: 0.4, height: 0.12),
            RecognizedLine("Amnesia Haze", x: 0.25, y: 0.72, width: 0.5, height: 0.05),
            RecognizedLine("Master Cut", x: 0.3, y: 0.65, width: 0.4, height: 0.05),
            RecognizedLine("THC 24%", x: 0.25, y: 0.5, width: 0.5, height: 0.04)
        ], codes: [])
        #expect(reading.name == "COG Amnesia Haze Master Cut")
    }
}
