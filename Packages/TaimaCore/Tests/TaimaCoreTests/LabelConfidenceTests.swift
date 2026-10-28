import Foundation
import Testing
@testable import TaimaCore

@Suite struct LabelConfidenceTests {
    func line(_ text: String, confidence: Double? = 0.95, alternatives: [RecognizedCandidate] = []) -> RecognizedLine {
        RecognizedLine(text, x: 0.15, y: 0.5, width: 0.6, height: 0.04, confidence: confidence, alternatives: alternatives)
    }

    @Test func confidenceUsesOnlySupportingOCR() throws {
        let clear = LabelParser.parse(lines: [line("THC 24%"), RecognizedLine("unrelated", x: 0.1, y: 0.1, width: 0.3, height: 0.02, confidence: 0.1)], codes: [])
        let doubtful = LabelParser.parse(lines: [line("THC 24%", confidence: 0.3)], codes: [])
        let exact = try #require(clear.confidence[.thc])
        #expect(exact.ocrConfidence == 0.95)
        #expect(exact.score > doubtful.confidence[.thc]!.score)
        #expect(!exact.needsReview)
        #expect(doubtful.confidence[.thc]?.needsReview == true)
        #expect(clear.confidence[.packedOn] == nil)
    }

    @Test func barcodeWinsAndCarriesItsSource() {
        let reading = LabelParser.parse(lines: [line("PRD-00000000-0000-4000-8000-000000000222", confidence: 0.2)], codes: [
            DetectedCode(kind: .qr, payload: "PRD-00000000-0000-4000-8000-000000000111")
        ])
        #expect(reading.productID?.hasSuffix("111") == true)
        #expect(reading.confidence[.productID]?.source == .barcode)
        #expect(reading.confidence[.productID]?.score == 0.99)
    }

    @Test func alternativeRescuesAnInvalidPrimary() {
        let reading = LabelParser.parse(lines: [line("THC 2S%", alternatives: [RecognizedCandidate("THC 25%", confidence: 0.9)])], codes: [])
        #expect(reading.thc == Potency(percent: 25))
        #expect(reading.confidence[.thc]?.usedAlternative == true)
        #expect(reading.confidence[.thc]?.ocrConfidence == 0.9)
    }

    @Test func alternativeRescuesProducerAndFullUUIDsAreNormalized() {
        let reading = LabelParser.parse(lines: [line("FITA", alternatives: [RecognizedCandidate("FYTA", confidence: 0.9)])], codes: [
            DetectedCode(kind: .qr, payload: "PRD-ABCDEF12-0000-4000-8000-000000000111")
        ])
        #expect(reading.producer == "FYTA")
        #expect(reading.confidence[.producer]?.usedAlternative == true)
        #expect(reading.productID == "prd-abcdef12-0000-4000-8000-000000000111")
    }

    @Test func conflictingValidCandidatesDoNotInventCertainty() {
        let reading = LabelParser.parse(lines: [line("THC 25%", alternatives: [RecognizedCandidate("THC 26%", confidence: 0.94)])], codes: [])
        #expect(reading.thc?.percent == 25)
        #expect(reading.confidence[.thc]?.isAmbiguous == true)
        #expect(reading.confidence[.thc]?.needsReview == true)
    }

    @Test func candidatesStayOnTheirObservationAndNeverVoteAsFrames() {
        let lines = [line("THC"), RecognizedLine("2S%", x: 0.8, y: 0.5, width: 0.1, height: 0.04, confidence: 0.92,
                                               alternatives: [RecognizedCandidate("25%", confidence: 0.9)])]
        let reading = LabelParser.parse(lines: lines, codes: [])
        var fusion = LabelFusion()
        fusion.add(reading)
        #expect(reading.thc?.percent == 25)
        #expect(fusion.frames == 1)
        #expect(!reading.text.contains("25%"))
    }

    @Test func labelAndValueCanBothUseAlternatives() {
        let reading = LabelParser.parse(lines: [
            RecognizedLine("TCH", x: 0.1, y: 0.5, width: 0.2, height: 0.04, confidence: 0.95,
                           alternatives: [RecognizedCandidate("THC", confidence: 0.9)]),
            RecognizedLine("2S%", x: 0.5, y: 0.5, width: 0.2, height: 0.04, confidence: 0.95,
                           alternatives: [RecognizedCandidate("25%", confidence: 0.9)])
        ], codes: [])
        #expect(reading.thc?.percent == 25)
        #expect(reading.confidence[.thc]?.usedAlternative == true)
    }

    @Test func oldLinesDecodeWithUnknownConfidence() throws {
        let data = Data(#"{"text":"THC 24%","box":{"x":0.1,"y":0.5,"width":0.4,"height":0.03}}"#.utf8)
        let old = try JSONDecoder().decode(RecognizedLine.self, from: data)
        #expect(old.confidence == nil && old.alternatives.isEmpty)
        #expect(try JSONDecoder().decode(RecognizedLine.self, from: JSONEncoder().encode(old)) == old)
        let reading = LabelParser.parse(lines: [old], codes: [])
        #expect(reading.confidence[.thc]?.needsReview == true)
    }

    @Test func oldPotencyBackupsDecodeAndRangesRoundTrip() throws {
        let old = try JSONDecoder().decode(Potency.self, from: Data(#"{"percent":24,"isUpperBound":false}"#.utf8))
        #expect(old == Potency(percent: 24))
        let range = Potency(percent: 26, lowerBound: 22, basis: .totalTHC)
        #expect(try JSONDecoder().decode(Potency.self, from: JSONEncoder().encode(range)) == range)
        #expect(range.label.contains("22") && range.label.contains("26"))
    }

    @Test func fusionEvidenceBelongsToTheWinningValue() {
        var fusion = LabelFusion()
        let winner = LabelParser.parse(lines: [line("THC 26%", confidence: 0.8)], codes: [])
        fusion.add(winner)
        fusion.add(winner)
        fusion.add(LabelParser.parse(lines: [line("THC 25%", confidence: 0.99)], codes: []))
        let result = fusion.reading
        #expect(result.thc?.percent == 26)
        #expect(result.confidence[.thc]?.ocrConfidence == 0.8)
        #expect(result.confidence[.thc]?.agreement == 2.0 / 3)
    }

    @Test func tiesAreStableAndFlagged() {
        var fusion = LabelFusion()
        fusion.add(LabelParser.parse(lines: [line("THC 25%")], codes: []))
        fusion.add(LabelParser.parse(lines: [line("THC 26%")], codes: []))
        for _ in 0..<10 {
            #expect(fusion.reading.thc?.percent == 25)
            #expect(fusion.reading.confidence[.thc]?.isAmbiguous == true)
        }
    }

    @Test func backMergeKeepsFrontEvidenceAndFillsMissingEvidence() {
        let front = LabelParser.parse(lines: [line("THC 24%", confidence: 0.8)], codes: [])
        let back = LabelParser.parse(lines: [line("THC 26% CBD <1%")], codes: [])
        let merged = front.merged(withBack: back)
        #expect(merged.thc == front.thc)
        #expect(merged.confidence[.thc] == front.confidence[.thc])
        #expect(merged.cbd == back.cbd)
        #expect(merged.confidence[.cbd] == back.confidence[.cbd])
    }

    @Test(arguments: [Double.nan, .infinity, -.infinity, -1, 2])
    func confidenceIsAlwaysBounded(_ value: Double) {
        let confidence = FieldConfidence(ocrConfidence: value, specificity: value, agreement: value)
        #expect((0...1).contains(confidence.score))
    }
}
