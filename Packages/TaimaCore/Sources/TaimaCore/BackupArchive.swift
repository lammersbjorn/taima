#if canImport(CommonCrypto)
import CommonCrypto
#else
import _CryptoExtras
#endif
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif
import Foundation

/// Backup format 2: a stream of records (one manifest, then one per photo),
/// written and read one record at a time so a large collection never sits
/// in memory. With a passphrase, every record is sealed with AES-GCM using a
/// key derived by PBKDF2-SHA256.
///
/// Layout: "TAIMABK2", mode byte (0 plain, 1 encrypted), then for encrypted
/// files a 16-byte salt and a big-endian UInt32 iteration count, then
/// records: big-endian UInt32 length + payload. A plain payload is a kind
/// byte (1 manifest, 2 photo), a big-endian UInt16 name length, the UTF-8
/// name and the data; an encrypted payload is that, sealed (combined form).
public enum BackupArchive {
    public static let fileExtension = "taimabackup"

    /// Photo names a restore may write: plain HEIC file names only, so a
    /// crafted backup can't write outside the photo folder.
    public static func isSafePhotoName(_ name: String) -> Bool {
        !name.isEmpty && !name.contains("/") && !name.contains("\\") && !name.hasPrefix(".") && name.hasSuffix(".heic")
    }
    static let magic = Data("TAIMABK2".utf8)
    public static let defaultIterations: UInt32 = 210_000

    public struct Manifest: Codable, Sendable {
        public var version: Int
        public var exportedAt: Date
        public var bags: [Bag]
        public var wishlist: [WishItem]
        public var producerKeys: [String: String]

        public init(bags: [Bag], wishlist: [WishItem], producerKeys: [String: String], exportedAt: Date = .now) {
            self.version = 2
            self.exportedAt = exportedAt
            self.bags = bags
            self.wishlist = wishlist
            self.producerKeys = producerKeys
        }
    }

    public enum ArchiveError: Error, LocalizedError, Equatable {
        case notABackup, needsPassphrase, wrongPassphrase, damaged

        public var errorDescription: String? {
            switch self {
            case .notABackup: String(localized: "This file is not a Taima backup.", bundle: .module)
            case .needsPassphrase: String(localized: "This backup is protected with a passphrase.", bundle: .module)
            case .wrongPassphrase: String(localized: "That passphrase doesn't open this backup.", bundle: .module)
            case .damaged: String(localized: "The backup file is damaged or incomplete.", bundle: .module)
            }
        }
    }

    // MARK: - Writing

    /// Writes the manifest and every photo `photo(name)` returns.
    public static func write(
        to url: URL, manifest: Manifest, photoNames: [String], photo: (String) throws -> Data?,
        passphrase: String?, iterations: UInt32 = defaultIterations
    ) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil, attributes: [.protectionKey: FileProtectionType.complete])
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        var header = magic
        var key: SymmetricKey?
        if let passphrase, !passphrase.isEmpty {
            // The system generator is cryptographically secure on every platform.
            var generator = SystemRandomNumberGenerator()
            let salt = Data((0..<16).map { _ in UInt8.random(in: .min ... .max, using: &generator) })
            header.append(1)
            header.append(salt)
            header.append(contentsOf: withUnsafeBytes(of: iterations.bigEndian, Array.init))
            key = try deriveKey(passphrase, salt: salt, iterations: iterations)
        } else {
            header.append(0)
        }
        try handle.write(contentsOf: header)

        func record(kind: UInt8, name: String, data: Data) throws {
            var payload = Data([kind])
            let nameData = Data(name.utf8)
            payload.append(contentsOf: withUnsafeBytes(of: UInt16(nameData.count).bigEndian, Array.init))
            payload.append(nameData)
            payload.append(data)
            if let key { payload = try AES.GCM.seal(payload, using: key).combined! }
            try handle.write(contentsOf: withUnsafeBytes(of: UInt32(payload.count).bigEndian, Array.init))
            try handle.write(contentsOf: payload)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        try record(kind: 1, name: "manifest.json", data: encoder.encode(manifest))
        for name in photoNames {
            try drainingPool {
                // nil means the file doesn't exist; an unreadable file throws.
                if let data = try photo(name) { try record(kind: 2, name: name, data: data) }
            }
        }
    }

    // MARK: - Reading

    public static func isEncrypted(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url), let head = try? handle.read(upToCount: 9) else { return false }
        try? handle.close()
        return head.count == 9 && head.prefix(8) == magic && head.last == 1
    }

    public static func isArchive(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url), let head = try? handle.read(upToCount: 8) else { return false }
        try? handle.close()
        return head == magic
    }

    /// Reads the manifest, handing each photo to `photo` as it streams past.
    public static func read(from url: URL, passphrase: String?, photo: (String, Data) throws -> Void) throws -> Manifest {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        func read(_ count: Int) throws -> Data {
            guard let data = try handle.read(upToCount: count), data.count == count else { throw ArchiveError.damaged }
            return data
        }
        guard try handle.read(upToCount: 8) == magic else { throw ArchiveError.notABackup }
        let mode = try read(1)[0]
        var key: SymmetricKey?
        if mode == 1 {
            let salt = try read(16)
            let iterations = try read(4).reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
            guard let passphrase, !passphrase.isEmpty else { throw ArchiveError.needsPassphrase }
            key = try deriveKey(passphrase, salt: salt, iterations: iterations)
        }

        var manifest: Manifest?
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        while let lengthData = try handle.read(upToCount: 4), !lengthData.isEmpty {
            guard lengthData.count == 4 else { throw ArchiveError.damaged }
            let length = Int(lengthData.reduce(UInt32(0)) { $0 << 8 | UInt32($1) })
            var payload = try read(length)
            if let key {
                do {
                    payload = try AES.GCM.open(AES.GCM.SealedBox(combined: payload), using: key)
                } catch {
                    throw manifest == nil ? ArchiveError.wrongPassphrase : ArchiveError.damaged
                }
            }
            guard payload.count >= 3 else { throw ArchiveError.damaged }
            let kind = payload[payload.startIndex]
            let nameLength = Int(payload[payload.startIndex + 1]) << 8 | Int(payload[payload.startIndex + 2])
            let nameStart = payload.startIndex + 3
            guard payload.count >= 3 + nameLength else { throw ArchiveError.damaged }
            let name = String(decoding: payload[nameStart..<(nameStart + nameLength)], as: UTF8.self)
            let body = payload[(nameStart + nameLength)...]
            switch kind {
            case 1: manifest = try decoder.decode(Manifest.self, from: Data(body))
            case 2: try photo(name, Data(body))
            default: continue
            }
        }
        guard let manifest else { throw ArchiveError.damaged }
        return manifest
    }

    static func deriveKey(_ passphrase: String, salt: Data, iterations: UInt32) throws -> SymmetricKey {
        #if canImport(CommonCrypto)
        var derived = Data(count: 32)
        let password = Array(passphrase.utf8)
        let status = derived.withUnsafeMutableBytes { output in
            salt.withUnsafeBytes { saltBytes in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2), password.map { Int8(bitPattern: $0) }, password.count,
                    saltBytes.bindMemory(to: UInt8.self).baseAddress, salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), iterations,
                    output.bindMemory(to: UInt8.self).baseAddress, 32
                )
            }
        }
        guard status == kCCSuccess else { throw ArchiveError.damaged }
        return SymmetricKey(data: derived)
        #else
        // swift-crypto's PBKDF2 gives the same key as CommonCrypto for the
        // same passphrase, salt and rounds, so backups open on both platforms.
        return try KDF.Insecure.PBKDF2.deriveKey(from: Data(passphrase.utf8), salt: salt, using: .sha256,
                                                  outputByteCount: 32, unsafeUncheckedRounds: Int(iterations))
        #endif
    }
}

/// Frees each photo's memory before the next on Apple platforms; elsewhere
/// there is no autorelease pool to drain.
@inline(__always)
private func drainingPool<T>(_ body: () throws -> T) rethrows -> T {
    #if canImport(ObjectiveC)
    try autoreleasepool(invoking: body)
    #else
    try body()
    #endif
}

