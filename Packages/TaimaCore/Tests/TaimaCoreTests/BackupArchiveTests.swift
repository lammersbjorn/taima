import Foundation
import Testing
@testable import TaimaCore

@Suite struct BackupArchiveTests {
    func fullBag() -> Bag {
        var bag = Bag(name: "Gelato", producer: "FYTA", strainType: .hybrid, thc: Potency(percent: 24), cbd: Potency(percent: 1, isUpperBound: true),
                      grams: 5, harvestedOn: Date(timeIntervalSince1970: 1_780_000_000), packedOn: Date(timeIntervalSince1970: 1_785_000_000),
                      productID: "prd-1", sku: "SKU-1", ean: "8721098003880", leafletURL: "https://x", priceEuros: 50, notes: "nice",
                      photoName: "a.heic", recognizedText: "text", backPhotoName: "b.heic", backRecognizedText: "back",
                      stock: .full, form: .jar, unitCount: nil, remainingGrams: 5)
        bag.use(0.3, details: UsageEntry(grams: 0, method: .vape, moodBefore: 2, moodAfter: 4, note: "n", withTobacco: false))
        bag.rating10 = 8.5
        bag.positiveEffects = ["Happy"]
        bag.negativeEffects = ["Dry mouth"]
        bag.flavorTags = ["Citrus"]
        bag.extraPhotoNames = ["c.heic"]
        bag.coverPhotoName = "c.heic"
        bag.shop = "Shop"
        bag.shopCity = "Breda"
        bag.wouldBuyAgain = true
        return bag
    }

    func roundTrip(passphrase: String?, readWith: String?, bag: Bag? = nil) throws -> (BackupArchive.Manifest, [String: Data]) {
        let url = FileManager.default.temporaryDirectory.appending(path: "t-\(UUID()).taimabackup")
        defer { try? FileManager.default.removeItem(at: url) }
        let bag = bag ?? fullBag()
        let manifest = BackupArchive.Manifest(bags: [bag], wishlist: [WishItem(key: "gelato", name: "Gelato")], producerKeys: ["tel:1": "FYTA"])
        try BackupArchive.write(to: url, manifest: manifest, photoNames: bag.photoNames, photo: { Data($0.utf8) }, passphrase: passphrase, iterations: 1000)
        var photos: [String: Data] = [:]
        let read = try BackupArchive.read(from: url, passphrase: readWith) { photos[$0] = $1 }
        return (read, photos)
    }

    @Test func everyFieldSurvives() throws {
        let original = fullBag()
        let (manifest, photos) = try roundTrip(passphrase: nil, readWith: nil, bag: original)
        let restored = manifest.bags[0]
        // ISO 8601 keeps whole seconds; every other field must match exactly.
        func normalized(_ bag: Bag) -> Bag {
            var bag = bag
            func second(_ date: Date) -> Date { Date(timeIntervalSince1970: date.timeIntervalSince1970.rounded(.down)) }
            bag.collectedOn = second(bag.collectedOn)
            bag.createdAt = second(bag.createdAt)
            bag.updatedAt = second(bag.updatedAt)
            bag.usageLog = bag.usageLog?.map { var e = $0; e.date = second(e.date); return e }
            return bag
        }
        #expect(normalized(restored) == normalized(original))
        #expect(restored.rating10 == 8.5 && restored.shop == "Shop" && restored.wouldBuyAgain == true)
        #expect(restored.usage.first?.method == .vape && restored.usage.first?.withTobacco == false)
        #expect(restored.extraPhotoNames == ["c.heic"] && restored.form == .jar)
        #expect(manifest.wishlist.map(\.key) == ["gelato"])
        #expect(manifest.producerKeys == ["tel:1": "FYTA"])
        #expect(photos.keys.sorted() == ["a.heic", "b.heic", "c.heic"])
        #expect(photos["b.heic"] == Data("b.heic".utf8))
    }

    @Test func encryptedRoundTrip() throws {
        let (manifest, photos) = try roundTrip(passphrase: "correct horse", readWith: "correct horse")
        #expect(manifest.bags.count == 1)
        #expect(photos.count == 3)
    }

    @Test func wrongOrMissingPassphrase() {
        #expect(throws: BackupArchive.ArchiveError.wrongPassphrase) { try roundTrip(passphrase: "secret phrase", readWith: "wrong phrase") }
        #expect(throws: BackupArchive.ArchiveError.needsPassphrase) { try roundTrip(passphrase: "secret phrase", readWith: nil) }
    }

    @Test func encryptedFilesHideContent() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "t-\(UUID()).taimabackup")
        defer { try? FileManager.default.removeItem(at: url) }
        try BackupArchive.write(to: url, manifest: .init(bags: [fullBag()], wishlist: [], producerKeys: [:]), photoNames: [], photo: { _ in nil }, passphrase: "secret phrase", iterations: 1000)
        let bytes = try Data(contentsOf: url)
        #expect(bytes.range(of: Data("Gelato".utf8)) == nil)
        #expect(BackupArchive.isEncrypted(url))
    }

    @Test func truncatedFileIsDamaged() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "t-\(UUID()).taimabackup")
        defer { try? FileManager.default.removeItem(at: url) }
        try BackupArchive.write(to: url, manifest: .init(bags: [fullBag()], wishlist: [], producerKeys: [:]), photoNames: ["a.heic"], photo: { Data($0.utf8) }, passphrase: nil)
        let data = try Data(contentsOf: url)
        try data.prefix(data.count - 3).write(to: url)
        #expect(throws: BackupArchive.ArchiveError.damaged) { try BackupArchive.read(from: url, passphrase: nil) { _, _ in } }
    }
}
