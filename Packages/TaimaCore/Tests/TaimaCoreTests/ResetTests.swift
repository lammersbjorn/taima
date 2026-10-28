#if canImport(SQLite3)
import SQLite3
import Foundation
import Testing
@testable import TaimaCore

@Suite struct ResetTests {
    @Test func eraseAllEmptiesEveryTable() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "taima-reset-\(UUID()).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try BagStore(url: url)
        try store.save(Bag(name: "Gelato"))
        try store.addWish(WishItem(key: "gelato", name: "Gelato"))
        try store.remember(producer: "FYTA", for: ["tel:416237000"])
        try store.eraseAll()
        let reopened = try BagStore(url: url)
        #expect(try reopened.allBags().isEmpty)
        #expect(try reopened.wishlist().isEmpty)
        #expect(try reopened.producer(for: ["tel:416237000"]) == nil)
        try reopened.save(Bag(name: "After reset"))
        #expect(try reopened.allBags().count == 1)
    }
}

@Suite struct IntegrityTests {
    @Test func unknownValuesFromNewerBuildsDecode() throws {
        let json = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","name":"Future","productForm":"tincture","stockState":"gifted","strainType":"ruderalis","collectedOn":0,"notes":"","recognizedText":"","createdAt":0,"updatedAt":0,"usageLog":[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FA","date":0,"grams":0.2,"method":"inhaler"}]}"#
        let bag = try JSONDecoder().decode(Bag.self, from: Data(json.utf8))
        #expect(bag.form == .bag)
        #expect(bag.stock == .empty)
        #expect(bag.usage.first?.method == .other)
    }

    @Test func unreadableRowsAreCountedAndKept() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "taima-bad-\(UUID()).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try BagStore(url: url)
        try store.save(Bag(name: "Good"))
        // A record no version can read.
        var db: OpaquePointer?
        sqlite3_open(url.path, &db)
        sqlite3_exec(db, "INSERT INTO bag (id, collected_on, body) VALUES ('x', 0, '{broken')", nil, nil, nil)
        sqlite3_close(db)
        #expect(try store.allBags().count == 1)
        #expect(store.unreadableCount == 1)
    }

    @Test func singleBagLookup() throws {
        let store = try BagStore(url: nil)
        let bag = Bag(name: "One")
        try store.save(bag)
        try store.save(Bag(name: "Two"))
        #expect(try store.bag(id: bag.id)?.name == "One")
    }

    @Test func mergeKeepsLoggedUse() {
        var original = Bag(name: "A", grams: 1, stock: .full)
        original.open()
        var stored = original
        stored.use(0.2)
        var edited = original
        edited.name = "A edited"
        let merged = Bag.merge(edited: edited, original: original, stored: stored)
        #expect(merged.name == "A edited")
        #expect(merged.usage.count == 1)
        #expect(merged.remaining == 0.8)
    }

    @Test func rescanKeepsEverythingPersonal() {
        var previous = Bag(name: "Old", priceEuros: 10, notes: "nice", photoName: "a.heic", stock: .open, form: .preroll, unitCount: 3, remainingGrams: 0.5)
        previous.rating10 = 8
        previous.shop = "Shop"
        previous.positiveEffects = ["Happy"]
        previous.extraPhotoNames = ["b.heic"]
        previous.wouldBuyAgain = true
        let fresh = Bag(name: "New name", thc: Potency(percent: 25), photoName: "a.heic").keepingPersonalFields(of: previous)
        #expect(fresh.id == previous.id)
        #expect(fresh.name == "New name")
        #expect(fresh.thc?.percent == 25)
        #expect(fresh.rating10 == 8 && fresh.shop == "Shop" && fresh.notes == "nice" && fresh.priceEuros == 10)
        #expect(fresh.positiveEffects == ["Happy"] && fresh.extraPhotoNames == ["b.heic"] && fresh.wouldBuyAgain == true)
        #expect(fresh.form == .preroll && fresh.unitCount == 3 && fresh.remaining == 0.5)
    }
}
#endif
