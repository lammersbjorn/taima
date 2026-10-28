import Foundation
import Testing
@testable import TaimaCore

@Suite struct WishlistTests {
    @Test func storesAndMigrates() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "taima-wish-\(UUID()).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try BagStore(url: url)
        try store.addWish(WishItem(key: "gelato", name: "Gelato"))
        try store.addWish(WishItem(key: "gelato", name: "Gelato"))
        #expect(try BagStore(url: url).wishlist().map(\.name) == ["Gelato"])
        try store.removeWish(key: "gelato")
        #expect(try store.wishlist().isEmpty)
    }

    @Test func oldBackupsDecode() throws {
        let data = try CollectionBackup(bags: [], photos: [:]).encoded()
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        json["wishlist"] = nil
        let backup = try CollectionBackup.decode(JSONSerialization.data(withJSONObject: json))
        #expect(backup.wishlist == nil)
    }
}
