#if canImport(SQLite3)
import Foundation
import Testing
@testable import TaimaCore

@Suite struct StoreAndStatsTests {
    @Test func savesUpdatesAndDeletes() throws {
        let store = try BagStore(url: nil)
        var bag = Bag(name: "Cali Mix", thc: Potency(percent: 24), grams: 5)
        try store.save(bag)
        bag.notes = "Citrus"
        try store.save(bag)
        #expect(try store.allBags() == [bag])
        try store.delete(id: bag.id)
        #expect(try store.allBags().isEmpty)
    }

    @Test func remembersProducers() throws {
        let store = try BagStore(url: nil)
        try store.remember(producer: "COG", for: ["tel:181729131", "ean:8721098"])
        #expect(try store.producer(for: ["domain:x.nl", "ean:8721098"]) == "COG")
        #expect(try store.producer(for: ["domain:x.nl"]) == nil)
    }

    @Test func persistsAcrossOpen() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "taima-\(UUID()).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let bag = Bag(name: "Speak Special")
        try BagStore(url: url).save(bag)
        #expect(try BagStore(url: url).allBags().map(\.id) == [bag.id])
    }

    @Test func stats() {
        let packed = LabelParser.dates(in: "01-09-2026")[0]
        let harvested = LabelParser.dates(in: "22-08-2026")[0]
        let bags = [
            Bag(name: "A", producer: "COG", thc: Potency(percent: 24), grams: 5, harvestedOn: harvested, packedOn: packed, priceEuros: 50),
            Bag(name: "B", producer: "COG", thc: Potency(percent: 28), grams: 1),
            Bag(name: "C", grams: 5)
        ]
        let stats = CollectionStats(bags: bags)
        #expect(stats.bagCount == 3)
        #expect(stats.totalGrams == 11)
        #expect(stats.averageTHC == 26)
        #expect(stats.highestTHC?.name == "B")
        #expect(stats.averageCureDays == 10)
        #expect(stats.averagePricePerGram == 10)
        #expect(stats.producers.first?.label == "COG")
        #expect(stats.sizes.first == .init(label: "5 g", count: 2, grams: 10))
        #expect(stats.thcBins.count == 5)
    }
}

@Suite struct BackupTests {
    @Test func roundTrips() throws {
        let bag = Bag(name: "Cali Mix", thc: Potency(percent: 24), photoName: "a.heic")
        let data = try CollectionBackup(bags: [bag], photos: ["a.heic": Data([1, 2, 3])]).encoded()
        let decoded = try CollectionBackup.decode(data)
        #expect(decoded.bags.map(\.id) == [bag.id])
        #expect(decoded.photos["a.heic"] == Data([1, 2, 3]))
    }

    @Test func rejectsOtherJSON() {
        #expect(throws: (any Error).self) { try CollectionBackup.decode(Data("{}".utf8)) }
    }

    @Test func csvHasNewScore() {
        var bag = Bag(name: "A")
        bag.rating10 = 7.5
        bag.positiveEffects = ["Happy", "Calm"]
        let csv = CSVExport.make([bag])
        #expect(csv.contains("7.5"))
        #expect(csv.contains("Happy; Calm"))
    }

    @Test func csvEscapes() {
        let csv = CSVExport.make([Bag(name: "A, \"B\"", notes: "x")])
        #expect(csv.contains("\"A, \"\"B\"\"\""))
    }
}

@Test func csvNeutralisesFormulas() {
    let csv = CSVExport.make([Bag(name: "=HYPERLINK(\"x\")", notes: "-3")])
    #expect(csv.contains("'=HYPERLINK"))
    #expect(csv.contains(",-3"))
}
#endif
