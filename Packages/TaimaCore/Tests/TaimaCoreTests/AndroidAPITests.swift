import Foundation
import Testing
@testable import TaimaCore

struct AndroidAPITests {
    func call(_ op: String, _ fields: [String: Any] = [:]) throws -> Any {
        var request = fields; request["version"] = 1; request["op"] = op
        let result = try JSONSerialization.jsonObject(with: AndroidAPI.call(JSONSerialization.data(withJSONObject: request))) as! [String: Any]
        #expect(result["ok"] as? Bool == true)
        return result["result"]!
    }
    @Test func mutationUsesInventoryRules() throws {
        let bag = Bag(name: "Synthetic jar", grams: 1, stock: .full, form: .jar)
        let record = try AndroidAPI.json(bag)
        let used = try call("bag.use", ["bag": record, "amount": 0.25])
        let decoded = try AndroidAPI.decode(Bag.self, used)
        #expect(decoded.remaining == 0.75)
        #expect(decoded.stock == .open)
        let undone = try call("bag.undo", ["bag": used, "id": decoded.usage[0].id.uuidString])
        #expect(try AndroidAPI.decode(Bag.self, undone).remaining == 1)
    }
    @Test func formCountsAreStructured() throws {
        let b = Bag(name: "Synthetic", grams: 2, form: .jar)
        let dashboard = try call("dashboard", ["bags": AndroidAPI.json([b])]) as! [String: Any]
        let forms = dashboard["formCounts"] as! [[String: Any]]
        #expect(forms.first { $0["form"] as? String == "jar" }?["count"] as? Int == 1)
        #expect(forms.allSatisfy { $0["label"] == nil })
    }
    @Test func partyStateSurvivesCalls() throws {
        var first = try call("party", ["action": "players", "names": ["Alex", "Bo", "Casey"], "language": "nl"]) as! [String: Any]
        first["action"] = "next"; first["language"] = "nl"
        let next = try call("party", first) as! [String: Any]
        #expect(next["card"] != nil)
        let state = try AndroidAPI.decode(DeckState.self, next["state"]!)
        #expect(state.dealt == 1)
        #expect(state.turn == 1)
        #expect(try AndroidAPI.decode(PartySettings.self, next["settings"]!).players.count == 3)
    }
    @Test func errorsAreEnvelopes() throws {
        let malformed = try JSONSerialization.jsonObject(with: AndroidAPI.call(Data("{".utf8))) as! [String: Any]
        #expect(malformed["ok"] as? Bool == false)
        let unsupported = try JSONSerialization.jsonObject(with: AndroidAPI.call(Data(#"{"version":1,"op":"not-an-operation"}"#.utf8))) as! [String: Any]
        #expect((unsupported["error"] as? [String: String])?["code"] == "unsupportedOperation")
    }
    @Test func bridgeBackupRoundTripUsesIOSGolden() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let work = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }
        let manifest = try call("backup.read", ["path": root.appendingPathComponent("contracts/golden/plain.taimabackup").path, "photoDirectory": work.path])
        let output = work.appendingPathComponent("roundtrip.taimabackup")
        _ = try call("backup.write", ["path": output.path, "photoDirectory": work.path, "manifest": manifest, "passphrase": "synthetic-only"])
        let restored = try call("backup.read", ["path": output.path, "photoDirectory": work.path, "passphrase": "synthetic-only"])
        #expect(try AndroidAPI.decode(BackupArchive.Manifest.self, restored).bags == AndroidAPI.decode(BackupArchive.Manifest.self, manifest).bags)
    }
}
