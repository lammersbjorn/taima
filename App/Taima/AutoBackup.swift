import Foundation
import Security
import TaimaCore
import UIKit

/// The backup passphrase in the Keychain, readable only on this iPhone
/// after its first unlock.
enum BackupKeychain {
    private static let account = "backup-passphrase"
    private static let service = "com.bjorn.taima"

    static var passphrase: String? {
        get {
            var result: AnyObject?
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                kSecAttrAccount as String: account, kSecReturnData as String: true
            ]
            guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        }
        set {
            let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
            SecItemDelete(query as CFDictionary)
            guard let newValue, !newValue.isEmpty else { return }
            var add = query
            add[kSecValueData as String] = Data(newValue.utf8)
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(add as CFDictionary, nil)
        }
    }
}

/// Daily backups to a folder the person picks (Files, iCloud Drive, a USB
/// drive), keeping the newest seven. A lapsed SideStore refresh or an
/// accidental delete then never loses more than a day.
@MainActor
enum AutoBackup {
    static let folderKey = "backup.folderBookmark"
    static let lastKey = "backup.last"
    static let errorKey = "backup.error"
    static let keep = 7
    // Keep the existing diagnostic cache stable; translate only when displayed.
    private static let timeoutMessage = "The last backup ran out of time and was discarded."

    static var lastError: String? {
        UserDefaults.standard.string(forKey: errorKey).map { message in
            message == timeoutMessage
                ? String(localized: "The last backup ran out of time and was discarded.") : message
        }
    }

    static var folderURL: URL? {
        guard let data = UserDefaults.standard.data(forKey: folderKey) else { return nil }
        var stale = false
        let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale)
        if stale, let url { try? setFolder(url) }
        return url
    }

    static var isOn: Bool { UserDefaults.standard.data(forKey: folderKey) != nil }

    static var lastBackup: Date? { UserDefaults.standard.object(forKey: lastKey) as? Date }

    static func setFolder(_ url: URL?) throws {
        guard let url else {
            UserDefaults.standard.removeObject(forKey: folderKey)
            return
        }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        UserDefaults.standard.set(try url.bookmarkData(), forKey: folderKey)
    }

    /// Runs when the app goes to the background, at most once a day.
    static func runIfDue(_ model: AppModel) {
        guard isOn, !model.bags.isEmpty else { return }
        if let last = lastBackup, Date.now.timeIntervalSince(last) < 20 * 3600 { return }
        /// Holds the task ID for the expiration handler, which is created first.
        final class Ticket: @unchecked Sendable { var id = UIBackgroundTaskIdentifier.invalid }
        let ticket = Ticket()
        let work = Task { await run(model) }
        ticket.id = UIApplication.shared.beginBackgroundTask(withName: "Taima backup") {
            // Out of time: stop; run() removes the partial file.
            work.cancel()
            UIApplication.shared.endBackgroundTask(ticket.id)
        }
        Task {
            await work.value
            UIApplication.shared.endBackgroundTask(ticket.id)
        }
    }

    static func run(_ model: AppModel) async {
        guard let folder = folderURL else { return }
        let access = folder.startAccessingSecurityScopedResource()
        defer { if access { folder.stopAccessingSecurityScopedResource() } }
        let stamp = Date.now.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false).timeSeparator(.omitted))
        let url = folder.appending(path: "Taima Backup \(stamp).\(BackupArchive.fileExtension)")
        // Written under a temporary name and renamed only when complete, so
        // an interrupted backup never counts as one of the kept seven.
        let partial = folder.appending(path: ".Taima Backup \(stamp).partial")
        do {
            try? FileManager.default.removeItem(at: partial)
            try await model.writeBackup(to: partial, passphrase: BackupKeychain.passphrase)
            try Task.checkCancellation()
            try? FileManager.default.removeItem(at: url)
            try FileManager.default.moveItem(at: partial, to: url)
            UserDefaults.standard.set(Date.now, forKey: lastKey)
            UserDefaults.standard.removeObject(forKey: errorKey)
            prune(folder)
        } catch {
            try? FileManager.default.removeItem(at: partial)
            UserDefaults.standard.set(error is CancellationError ? timeoutMessage : error.localizedDescription, forKey: errorKey)
        }
    }

    /// Keeps the newest backups Taima made; never touches other files.
    private static func prune(_ folder: URL) {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        // Leftover partial files from a crash go too; they never restore.
        for leftover in files where leftover.lastPathComponent.hasPrefix(".Taima Backup ") && leftover.pathExtension == "partial" {
            try? FileManager.default.removeItem(at: leftover)
        }
        let ours = files.filter { $0.lastPathComponent.hasPrefix("Taima Backup ") && $0.pathExtension == BackupArchive.fileExtension }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        for old in ours.dropFirst(keep) { try? FileManager.default.removeItem(at: old) }
    }
}

/// Keeps Taima's data out of iCloud device backups when the person asks.
enum DeviceBackupExclusion {
    static let key = "backup.excludeFromICloud"

    static func apply(_ exclude: Bool) {
        var urls = [StorePaths.folder]
        if let shared = SharedContainer.url { urls.append(shared) }
        for var url in urls {
            var values = URLResourceValues()
            values.isExcludedFromBackup = exclude
            try? url.setResourceValues(values)
        }
    }
}
