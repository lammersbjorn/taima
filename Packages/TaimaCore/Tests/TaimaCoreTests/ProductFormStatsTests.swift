import Foundation
import Testing
@testable import TaimaCore

@Suite struct ProductFormStatsTests {
    private func item(_ name: String, _ form: ProductForm, thc: Double, grams: Double, price: Double? = nil, units: Int? = nil) -> Bag {
        Bag(name: name, thc: Potency(percent: thc), grams: grams, priceEuros: price, form: form, unitCount: units)
    }

    @Test func countsNameWhatWasCollected() {
        let bags = [item("A", .bag, thc: 20, grams: 5), item("B", .bag, thc: 22, grams: 5)]
        #expect(ItemCount.label(bags) == "2 bags")
        #expect(ItemCount.breakdown(bags) == nil)
        let mixed = bags + [item("C", .preroll, thc: 20, grams: 1, units: 2), item("D", .hash, thc: 45, grams: 1)]
        #expect(ItemCount.label(mixed) == "4 items")
        #expect(ItemCount.breakdown(mixed) == "2 bags, 1 preroll pack, and 1 piece of hash")
        #expect(ProductForm.jar.counted(1) == "1 jar")
    }

    @Test func hashStaysOutOfFlowerTHCAndPrice() {
        let stats = CollectionStats(bags: [
            item("Flower", .bag, thc: 20, grams: 5, price: 50),
            item("Joints", .preroll, thc: 24, grams: 1, price: 12, units: 2),
            item("Hash", .hash, thc: 50, grams: 1, price: 30),
        ])
        #expect(stats.averageTHC == 22)
        #expect(stats.highestTHC?.name == "Joints")
        #expect(stats.averageHashTHC == 50 && stats.hashCount == 1)
        #expect(stats.thcBins.map(\.lowerBound).max() == 24)
        #expect(stats.averagePricePerGram == 11)
    }

    @Test func sizesSayWhatTheyAre() {
        let stats = CollectionStats(bags: [
            item("Flower", .bag, thc: 20, grams: 1),
            item("Joints", .preroll, thc: 24, grams: 1, units: 2),
            item("Pot", .jar, thc: 20, grams: 3.5),
        ])
        let half = 0.5.formatted(.number.precision(.fractionLength(0...2)))
        let jar = 3.5.formatted(.number.precision(.fractionLength(0...2)))
        #expect(Set(stats.sizes.map(\.label)) == ["1 g", "2 × \(half) g prerolls", "\(jar) g jar"])
    }

    @Test func unnamedItemsSayWhatTheyAre() {
        #expect(Bag(form: .preroll).displayName == "Unnamed preroll pack")
        #expect(Bag().displayName == "Unnamed bag")
    }
}
