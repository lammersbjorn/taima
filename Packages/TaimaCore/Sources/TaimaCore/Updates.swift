#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif
import Foundation

/// The SideStore/AltStore source that lists Taima's releases. The same file
/// SideStore reads to update the app tells Taima a newer version exists.
public struct SourceFeed: Decodable, Sendable {
    public struct App: Decodable, Sendable {
        public var bundleIdentifier: String
        public var versions: [Version]?
    }

    public struct Version: Decodable, Sendable, Equatable {
        public var version: String
        public var buildVersion: String?
        public var date: String?
        public var localizedDescription: String?
        public var downloadURL: String?

        public var build: Int { Int(buildVersion ?? "") ?? 0 }
    }

    public var apps: [App]

    public static func decode(_ data: Data) throws -> SourceFeed {
        try JSONDecoder().decode(SourceFeed.self, from: data)
    }

    /// The newest listed version of an app, if it is newer than `build`.
    public func update(for bundleIdentifier: String, currentBuild: Int) -> Version? {
        guard let latest = apps.first(where: { $0.bundleIdentifier == bundleIdentifier })?
            .versions?.max(by: { $0.build < $1.build }), latest.build > currentBuild else { return nil }
        return latest
    }
}

/// A published strain library: a version and the checksum of every file.
/// Taima installs a download only if every file matches and the data loads.
public struct CatalogManifest: Codable, Sendable, Equatable {
    public struct File: Codable, Sendable, Equatable {
        public var name: String
        public var sha256: String
        public var size: Int
    }

    public var version: Int
    public var generated: String?
    /// The oldest app build that understands this data.
    public var minimumBuild: Int?
    public var strainCount: Int?
    public var files: [File]

    public static func decode(_ data: Data) throws -> CatalogManifest {
        try JSONDecoder().decode(CatalogManifest.self, from: data)
    }

    /// Plain names only, so a manifest can't point outside the library folder.
    public var isWellFormed: Bool {
        !files.isEmpty && files.allSatisfy { file in
            !file.name.isEmpty && !file.name.contains("/") && !file.name.contains("\\") && !file.name.hasPrefix(".") && file.name.hasSuffix(".json")
        }
    }

    public static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public func verify(_ data: Data, for file: File) -> Bool {
        data.count == file.size && Self.sha256(data) == file.sha256.lowercased()
    }
}

/// The provisioning profile SideStore or iloader embeds when signing Taima.
/// Its `ExpirationDate` is when iOS stops opening this copy. Only the
/// property list inside is read; nothing is verified or sent anywhere.
public enum EmbeddedProfile {
    public static let maxBytes = 512 * 1024

    public static func expirationDate(in data: Data) -> Date? {
        guard data.count <= maxBytes,
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.upperBound..<data.endIndex),
              let plist = try? PropertyListSerialization.propertyList(from: data.subdata(in: start.lowerBound..<end.upperBound), format: nil) as? [String: Any]
        else { return nil }
        return plist["ExpirationDate"] as? Date
    }
}

/// When to remind about refreshing the signature, after Saiko 2.
public enum RefreshPolicy {
    /// Stash names the expiry in the final 48 hours.
    public static let warningWindow: TimeInterval = 48 * 3600
    public static let reminderHour = 10

    public enum Notice: Equatable, Sendable {
        case expiresSoon(Date)
        case expired(Date)
    }

    public static func notice(expiry: Date?, now: Date = .now) -> Notice? {
        guard let expiry else { return nil }
        if expiry <= now { return .expired(expiry) }
        return expiry.timeIntervalSince(now) <= warningWindow ? .expiresSoon(expiry) : nil
    }

    /// 10:00 on the day before expiry, or nil once that has passed.
    public static func reminderDate(expiry: Date?, now: Date = .now, calendar: Calendar = .current) -> Date? {
        guard let expiry,
              let dayBefore = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: expiry)),
              let fire = calendar.date(bySettingHour: reminderHour, minute: 0, second: 0, of: dayBefore),
              fire > now else { return nil }
        return fire
    }
}
