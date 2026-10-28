import Foundation
import Testing
@testable import TaimaCore

@Suite struct LearningTests {
    @Test func learnsSpellingFixesNotRenames() {
        var memory = CorrectionMemory()
        memory.learn(read: "Pheno Hunt Miix", saved: "Pheno Hunt Mix")
        memory.learn(read: "CQG Amnesia", saved: "COG Amnesia")
        memory.learn(read: "Cali Mix", saved: "Something Else Entirely")
        memory.learn(read: "Gelato", saved: "Gelato #33")
        #expect(memory.words == ["miix": "Mix", "cqg": "COG"])
        #expect(memory.apply(to: "Super Miix") == "Super Mix")
        memory.forget("miix")
        #expect(memory.apply(to: "Super Miix") == "Super Miix")
    }

    @Test func sampleCarriesOnlyCorrectionsAndRedactedText() throws {
        var reading = LabelReading()
        reading.name = "Pheno Hunt Miix"
        reading.thc = Potency(percent: 25)
        reading.grams = 5
        reading.text = "Pheno Hunt Miix 5 grarn\nTHC: 25%\nPRD-00000000-0000-4000-8000-000000000201 PHMX\n8721098003880"
        var bag = Bag(name: "Pheno Hunt Mix", thc: Potency(percent: 26), grams: 5, priceEuros: 40, notes: "private")
        bag.shop = "Shop"
        let sample = try #require(LabelSample.make(reading: reading, saved: bag, appVersion: "1.6"))
        #expect(sample.fields.map(\.field) == ["name", "thc"])
        #expect(!sample.text.contains("000000000201") && !sample.text.contains("8721098003880"))
        #expect(!sample.json.contains("private") && !sample.json.contains("Shop") && !sample.json.contains("40"))
    }

    // Made-up codes, in the shapes text recognition returns.
    @Test(arguments: [
        "PRD-1a2b3c4d-5e6l-4a7b-8c9d-0e1f2a3b4c5d",
        "PRD-1a2b3c4d-5e6f-4a7b-\n8c9d-0e1f2a3b4c5d",
        "PRD 1a2b3c4d-5e6f-4a7b-8c9d-0e1f2a3b4c5d",
        "PR0-1a2b3c4d-5e6f-4a7b-8c9d-0e1f2a3b4c5d",
        "EAN 8 712345 678906",
        "EAN8712345678906",
    ])
    func redactionCatchesMisreadCodes(_ text: String) {
        let redacted = LabelSample.redact(text)
        for piece in ["1a2b3c4d", "5e6", "4a7b", "8c9d", "0e1f2a3b4c5d", "712345", "678906"] {
            #expect(!redacted.contains(piece), "\(piece) left in \(redacted)")
        }
    }

    @Test func redactionKeepsLabelText() {
        let text = "Girl Scout Cookie\nTHC 24%\nGeoogst: 02-07-2026\nPHMX-FLW-50G\nAmnesia-Haze"
        #expect(LabelSample.redact(text) == text)
    }

    @Test func noCorrectionsNoSample() {
        var reading = LabelReading()
        reading.name = "Gelato"
        reading.text = "Gelato"
        #expect(LabelSample.make(reading: reading, saved: Bag(name: "Gelato"), appVersion: "1") == nil)
    }
}
