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
    @Test(arguments: ProductForm.allCases) func methodsMatchItemModel(_ form: ProductForm) throws {
        let b = Bag(name: "Synthetic item", grams: 2, stock: .full, form: form)
        let view = try call("bag.view", ["bag": AndroidAPI.json(b)]) as! [String: Any]
        #expect(view["methods"] as? [String] == ConsumptionMethod.suiting(form).map(\.rawValue))
        #expect(view["isWeighed"] as? Bool == form.isWeighed)
    }
    @Test func edibleEditingAndQuickUseStayInPieces() throws {
        let draft = Bag(name: "Synthetic edible", stock: .full)
        let record = try call("bag.edit", ["bag": AndroidAPI.json(draft), "locale": "nl-NL", "fields": [
            "name": "Synthetic edible", "productForm": "edible", "stockState": "full", "grams": "4", "thcMilligrams": "7,5"
        ]])
        let edited = try AndroidAPI.decode(Bag.self, record)
        #expect(edited.form == .edible && edited.grams == 4 && edited.thcMilligrams == 7.5)
        let used = try call("bag.use", ["bag": record, "amount": 0.5])
        let b = try AndroidAPI.decode(Bag.self, used)
        #expect(b.remaining == 3.5 && b.usage.first?.method == .edible)
        let summary = try call("dashboard", ["bags": AndroidAPI.json([b])]) as! [String: Any]
        #expect(summary["grams"] as? Double == 0 && summary["stash"] as? Double == 0 && summary["usedToday"] as? Double == 0)
    }
    @Test func sessionEditingPreservesInventoryAndAmount() throws {
        var b = Bag(name: "Synthetic jar", grams: 2, stock: .full, form: .jar)
        b.use(0.25)
        var entry = b.usage[0]; entry.grams = 99; entry.method = .vape; entry.note = "Synthetic note"; entry.moodAfter = 4
        let changed = try call("bag.session", ["bag": AndroidAPI.json(b), "entry": AndroidAPI.json(entry)])
        let result = try AndroidAPI.decode(Bag.self, changed)
        #expect(result.remaining == b.remaining && result.usage[0].grams == 0.25)
        #expect(result.usage[0].note == "Synthetic note" && result.usage[0].moodAfter == 4)
    }
    @Test func potencyMetadataCanBeEditedExplicitly() throws {
        let draft = Bag(name: "Synthetic", stock: .full)
        let changed = try call("bag.edit", ["bag": AndroidAPI.json(draft), "locale": "en-US", "fields": [
            "name": "Synthetic", "thc": "24", "thcLower": "20", "thcUpper": "false", "thcBasis": "totalTHC", "cbd": "1", "cbdLower": "", "cbdUpper": "true"
        ]])
        let result = try AndroidAPI.decode(Bag.self, changed)
        #expect(result.thc == Potency(percent: 24, lowerBound: 20, basis: .totalTHC))
        #expect(result.cbd == Potency(percent: 1, isUpperBound: true))
    }
    @Test func collectionFiltersAndGroupsUseSharedStrainKeys() throws {
        let first = Bag(name: "Synthetic Alpha", grams: 2, stock: .full, form: .jar)
        let second = Bag(name: "Synthetic Alpha", grams: 20, stock: .full, form: .edible)
        let result = try call("collection", ["bags": AndroidAPI.json([first, second]), "sort": "heaviest"]) as! [String: Any]
        #expect(try AndroidAPI.decode([Bag].self, result["bags"]!).first?.id == first.id)
        let groups = result["groups"] as! [[String: Any]]
        #expect(groups.count == 1 && groups[0]["grams"] as? Double == 2)
        let filtered = try call("collection", ["bags": AndroidAPI.json([first, second]), "form": "edible", "stock": "full"]) as! [String: Any]
        #expect(try AndroidAPI.decode([Bag].self, filtered["bags"]!).map(\.id) == [second.id])
    }
    @Test func multiFrameCodesReachFusion() throws {
        let code = DetectedCode(kind: .ean, payload: "0000000000000")
        let response = try call("label.frames", ["frames": [["lines": [], "codes": try AndroidAPI.json([code])]]]) as! [String: Any]
        #expect(try AndroidAPI.decode(Bag.self, response["bag"]!).ean == code.payload)
    }
    @Test func rouletteBridgeNeverSpinsAnEdible() throws {
        let edible = Bag(name: "Synthetic edible", grams: 8, stock: .full, form: .edible)
        for _ in 0..<25 {
            let response = try call("party", ["action": "roulette", "bags": AndroidAPI.json([edible])]) as! [String: Any]
            let spin = try AndroidAPI.decode(RouletteSpin.self, response["roulette"]!)
            #expect(spin.bagID == nil)
        }
    }

    @Test func backOCRFillsGapsWithoutReplacingFrontOrTypedFields() throws {
        let b = Bag(name: "Typed synthetic name", thc: Potency(percent: 20), grams: 2, ean: "0000000000000", recognizedText: "Synthetic front")
        let line = RecognizedLine("THC: 24.0%", LabelBox(x: 0, y: 0, width: 1, height: 0.1))
        let response = try call("label", ["bag": AndroidAPI.json(b), "back": true, "lines": AndroidAPI.json([line]), "codes": AndroidAPI.json([DetectedCode(kind: .ean, payload: "0000000000017")])]) as! [String: Any]
        let result = try AndroidAPI.decode(Bag.self, response["bag"]!)
        #expect(result.name == b.name && result.thc == b.thc && result.ean == b.ean)
        #expect(result.recognizedText == b.recognizedText && result.backRecognizedText?.contains("24.0%") == true)
    }

    @Test func widgetCountsAndLogsWholeEdiblePieces() throws {
        var b = Bag(name: "Synthetic edible", grams: 4, stock: .full, form: .edible)
        b.use(0.5)
        let view = try call("bag.view", ["bag": AndroidAPI.json(b)]) as! [String: Any]
        #expect(view["widgetUnit"] as? Double == 1)
        #expect(view["widgetUnit"] as? Double == WidgetSnapshot(bags: [b], hasThumbnail: false, currentID: b.id).current?.unitGrams)
        #expect(view["widgetUnitsLeft"] as? Int == 3)
        let result = try call("bag.use", ["bag": AndroidAPI.json(b), "amount": view["widgetUnit"]!])
        #expect(try AndroidAPI.decode(Bag.self, result).remaining == 2.5)
    }

    @Test func correctionMemoryAndAcceptedReviewUseSharedRules() throws {
        let learned = try call("learning", ["action": "learn", "read": "Synthetic Miix", "saved": "Synthetic Mix"]) as! [String: Any]
        let applied = try call("learning", ["memory": learned["memory"]!, "name": "Miix"]) as! [String: Any]
        #expect(applied["name"] as? String == "Mix")
        var b = Bag(name: "Typed synthetic", thc: Potency(percent: 20))
        b.collectedOn = Date(timeIntervalSince1970: 1_700_000_000)
        let lines = [RecognizedLine("THC: 24%", LabelBox(x: 0, y: 0, width: 1, height: 0.1)),
                     RecognizedLine("CBD: 1%", LabelBox(x: 0, y: 0.2, width: 1, height: 0.1))]
        let review = try call("label.review", ["bag": AndroidAPI.json(b), "lines": AndroidAPI.json(lines)]) as! [String: Any]
        let updated = try AndroidAPI.decode(Bag.self, review["bag"]!)
        #expect(updated.name == b.name && updated.thc == b.thc)
        #expect(updated.cbd?.percent == 1)
        #expect(updated.id == b.id && updated.collectedOn == b.collectedOn)
    }

    @Test func offeredSamplesUseSharedRedactionAndExcludePersonalFields() throws {
        let original = Bag(name: "Synthetic Miix", recognizedText: "Synthetic Miix\nTHC: 20%\nPRD-00000000-0000-4000-8000-000000000000")
        var saved = original; saved.name = "Synthetic Mix"; saved.notes = "PRIVATE-NOTE"; saved.shop = "PRIVATE-SHOP"; saved.priceEuros = 9876
        let sample = try #require(try call("label.sample", ["original": AndroidAPI.json(original), "bag": AndroidAPI.json(saved), "appVersion": "synthetic"]) as? String)
        #expect(sample.contains("Synthetic Mix"))
        for value in ["00000000-0000-4000-8000-000000000000", "PRIVATE-NOTE", "PRIVATE-SHOP", "9876"] { #expect(!sample.contains(value)) }
    }

}
