import Foundation
import SQLite3
import Testing
@testable import TaimaCore

@Suite struct EngineeringTests {
    @Test func photoNamesFromBackupsAreChecked() {
        #expect(BackupArchive.isSafePhotoName("A1B2.heic"))
        #expect(!BackupArchive.isSafePhotoName("../x.heic"))
        #expect(!BackupArchive.isSafePhotoName("sub/x.heic"))
        #expect(!BackupArchive.isSafePhotoName(".hidden.heic"))
        #expect(!BackupArchive.isSafePhotoName("x.jpg"))
        #expect(!BackupArchive.isSafePhotoName(""))
    }

    @Test func migratesVersionOneDatabase() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "taima-v1-\(UUID()).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        // A database as build 1 left it: bag and producer_key, user_version 1.
        var db: OpaquePointer?
        sqlite3_open(url.path, &db)
        let body = String(decoding: try JSONEncoder().encode(Bag(name: "Old")), as: UTF8.self).replacingOccurrences(of: "'", with: "''")
        sqlite3_exec(db, """
            CREATE TABLE bag (id TEXT PRIMARY KEY NOT NULL, collected_on REAL NOT NULL, body TEXT NOT NULL);
            CREATE TABLE producer_key (key TEXT PRIMARY KEY NOT NULL, producer TEXT NOT NULL);
            INSERT INTO bag VALUES ('a', 0, '\(body)');
            PRAGMA user_version = 1;
            """, nil, nil, nil)
        sqlite3_close(db)
        let store = try BagStore(url: url)
        #expect(try store.allBags().map(\.name) == ["Old"])
        try store.addWish(WishItem(key: "gelato", name: "Gelato"))
        #expect(try store.wishlist().count == 1)
    }

    @Test func freshDatabaseFromNothing() throws {
        let store = try BagStore(url: nil)
        try store.addWish(WishItem(key: "k", name: "K"))
        try store.remember(producer: "FYTA", for: ["tel:1"])
        #expect(try store.producerKeys() == ["tel:1": "FYTA"])
    }

    @Test func discreetSnapshotIsRedactedWhenWritten() {
        var bag = Bag(name: "Secret Haze", producer: "FYTA", thc: Potency(percent: 25), grams: 5, stock: .full)
        bag.open()
        let snapshot = WidgetSnapshot(bags: [bag], hasThumbnail: true, currentID: bag.id)
        #expect(snapshot.current?.name == "Secret Haze")
        let redacted = snapshot.redacted()
        let json = String(decoding: try! JSONEncoder().encode(redacted), as: UTF8.self)
        #expect(!json.contains("Secret") && !json.contains("FYTA") && !json.contains("25%"))
        #expect(redacted.latest?.hasThumbnail == false)
        #expect(redacted.stashGrams == snapshot.stashGrams)
        #expect(redacted.symbol == "circle.hexagongrid.fill")
    }
}
