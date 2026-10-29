import Foundation
import Testing
@testable import TaimaCore
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

@Suite(.serialized) struct ContractGoldenTests {
    private func file(_ name: String) -> URL { TestResources.contracts.appendingPathComponent(name) }
    private func data(_ name: String) throws -> Data { try Data(contentsOf: file(name)) }
    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601; return decoder
    }
    private func encoder() -> JSONEncoder {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]; return encoder
    }
    private func check(_ name: String, _ actual: Data) throws {
        if ProcessInfo.processInfo.environment["TAIMA_REGENERATE_GOLDENS"] == "1" { try actual.write(to: file(name)) }
        #expect(try data(name) == actual)
    }

    @Test func recordCSVAndManifest() throws {
        let bag = try decoder().decode(Bag.self, from: data("record.json"))
        try check("record.json", encoder().encode(bag))
        try check("collection.csv", Data(CSVExport.make([bag]).utf8))
        let imported = try #require(CSVExport.parse(String(decoding: data("collection.csv"), as: UTF8.self)).first)
        #expect(imported.name == bag.name && imported.grams == bag.grams && imported.thc == bag.thc)
        #expect(imported.stock == .empty && imported.usage.isEmpty)
        var edible = bag; edible.form = .edible; edible.thcMilligrams = 7.5
        try check("edible-record.json", encoder().encode(edible))
        try check("edible.csv", Data(CSVExport.make([edible]).utf8))
        let importedEdible = try #require(CSVExport.parse(String(decoding: data("edible.csv"), as: UTF8.self)).first)
        #expect(importedEdible.form == .edible && importedEdible.thcMilligrams == 7.5)
        #expect(importedEdible.grams == edible.grams)
        let manifest = try CatalogManifest.decode(data("catalog-manifest.json"))
        #expect(manifest.isWellFormed)
        for entry in manifest.files {
            #expect(try manifest.verify(data(entry.name), for: entry))
            #expect(!manifest.verify(Data("changed".utf8), for: entry))
        }
    }

    @Test func backupBytesAndCrypto() throws {
        let bag = try decoder().decode(Bag.self, from: data("record.json"))
        let date = try #require(ISO8601DateFormatter().date(from: "2026-03-29T01:30:00Z"))
        let manifest = BackupArchive.Manifest(bags: [bag], wishlist: [], producerKeys: [:], exportedAt: date)
        let body = try encoder().encode(manifest)
        try check("manifest.json", body)
        let photoName = "00000000-0000-4000-8000-000000000003.heic"
        let photoBytes = try data("photo.heic")
        func payload(_ kind: UInt8, _ name: String, _ body: Data) -> Data {
            var result = Data([kind, UInt8(name.utf8.count >> 8), UInt8(name.utf8.count & 255)])
            result.append(Data(name.utf8)); result.append(body); return result
        }
        let payloads = [payload(1, "manifest.json", body), payload(2, photoName, photoBytes)]
        func archive(_ encrypted: Bool) throws -> Data {
            var output = Data("TAIMABK2".utf8); output.append(encrypted ? 1 : 0)
            var key: SymmetricKey?
            if encrypted {
                let salt = Data(0..<16)
                output.append(salt); output.append(contentsOf: [0, 3, 52, 80])
                key = try BackupArchive.deriveKey("taima-é-🌿", salt: salt, iterations: 210_000)
                try key!.withUnsafeBytes { try check("pbkdf2.hex", Data($0.map { String(format: "%02x", $0) }.joined().utf8)) }
            }
            for (index, payload) in payloads.enumerated() {
                var record = payload
                if let key {
                    let start = 16 + index * 12
                    let nonce = Data((start..<(start + 12)).map(UInt8.init))
                    record = try #require(AES.GCM.seal(payload, using: key, nonce: AES.GCM.Nonce(data: nonce)).combined)
                }
                var length = UInt32(record.count).bigEndian
                withUnsafeBytes(of: &length) { output.append(contentsOf: $0) }; output.append(record)
            }
            return output
        }
        try check("plain.taimabackup", archive(false))
        try check("encrypted.taimabackup", archive(true))
        for (name, passphrase) in [("plain.taimabackup", Optional<String>.none), ("encrypted.taimabackup", "taima-é-🌿")] {
            let read = try BackupArchive.read(from: file(name), passphrase: passphrase, photo: { name, bytes in #expect(name == photoName && bytes == photoBytes) })
            #expect(read.bags == [bag] && read.version == 2)
            let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: temporary) }
            try BackupArchive.write(to: temporary, manifest: read, photoNames: [photoName], photo: { _ in photoBytes }, passphrase: passphrase)
            #expect(try BackupArchive.read(from: temporary, passphrase: passphrase, photo: { _, _ in }).bags == [bag])
            if passphrase == nil { #expect(try Data(contentsOf: temporary) == data("plain.taimabackup")) }
        }
        #expect(throws: BackupArchive.ArchiveError.wrongPassphrase) {
            try BackupArchive.read(from: file("encrypted.taimabackup"), passphrase: "wrong", photo: { _, _ in })
        }
    }

    @Test func amsterdamDaylightSaving() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Amsterdam"))
        let before = try #require(ISO8601DateFormatter().date(from: "2026-03-28T11:00:00Z"))
        let after = try #require(calendar.date(byAdding: .day, value: 1, to: before))
        #expect(after.timeIntervalSince(before) == 23 * 3600)
        #expect(calendar.component(.hour, from: after) == 12)
        for text in ["1.5", "1,5"] { #expect(CSVExport.parse("name;grams\nExample;\(text)\n").first?.grams == 1.5) }
        #expect(CSVExport.parse("name;grams\nExample;1,000.5\n").first?.grams == nil)
    }

    @Test(arguments: ["nl_NL", "de_DE", "en_US"])
    func localeNumbers(_ identifier: String) throws {
        let locale = Locale(identifier: identifier)
        let input = identifier == "en_US" ? "1.5" : "1,5"
        #expect(DecimalInput.parse(input, locale: locale) == 1.5)
        #expect(DecimalInput.parse(identifier == "en_US" ? "1,5" : "1.5", locale: locale) == nil)
        #expect(DecimalInput.parse("1,000.5", locale: locale) == nil)
        #expect(DecimalInput.parse("1.000,5", locale: locale) == nil)
        let bag = try decoder().decode(Bag.self, from: data("record.json"))
        #expect(try Data(CSVExport.make([bag]).utf8) == data("collection.csv"))
    }
}
