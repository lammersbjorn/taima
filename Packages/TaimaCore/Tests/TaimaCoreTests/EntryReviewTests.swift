import Foundation
import Testing
@testable import TaimaCore

@Suite struct EntryReviewTests {
    @Test func offersOnlyEmptyFields() throws {
        let bag = Bag(name: "Cali Mix", thc: Potency(percent: 23), grams: nil)
        var reading = LabelReading()
        reading.name = "Something else"
        reading.thc = Potency(percent: 24)
        reading.grams = 5
        reading.productID = "prd-1"
        let suggestion = try #require(EntryReview.suggest(for: bag, reading: reading, libraryType: .sativa))
        #expect(suggestion.updated.name == "Cali Mix")
        #expect(suggestion.updated.thc?.percent == 23)
        #expect(suggestion.updated.grams == 5)
        #expect(suggestion.updated.strainType == .sativa)
        #expect(Set(suggestion.changes.map(\.field)) == ["Type", "Weight", "Product code"])
    }

    @Test func fixesOldNameReadings() throws {
        let suggestion = try #require(EntryReview.suggest(for: Bag(name: "CQG Amnesia Haze Master Cut"), reading: LabelReading(), grower: "Canadelaar"))
        #expect(suggestion.updated.name == "COG Amnesia Haze Master Cut")
        #expect(suggestion.updated.producer == "Canadelaar")
    }

    @Test func nothingNewMeansNoSuggestion() {
        var reading = LabelReading()
        reading.name = "Gelato"
        #expect(EntryReview.suggest(for: Bag(name: "Gelato"), reading: reading) == nil)
    }
}
