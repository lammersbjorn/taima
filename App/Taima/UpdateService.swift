import Foundation
import Observation
import TaimaCore
import UserNotifications

/// Where releases and the strain library are published. Everything is a
/// plain file on GitHub: Taima downloads it and sends nothing about you.
enum Published {
    static let repository = "lammersbjorn/taima"
    static let raw = URL(string: "https://raw.githubusercontent.com/\(repository)/main/")!
    static let sourceURL = raw.appending(path: "sidestore/source.json")
    static let libraryURL = raw.appending(path: "catalog/v1/")
    static let releases = URL(string: "https://github.com/\(repository)/releases")!
}

/// The daily check for a new Taima version and a newer strain library,
/// and the reminders to refresh the signature before it lapses.
@MainActor
@Observable
final class UpdateService {
    static let checkKey = "updates.check"
    static let autoLibraryKey = "updates.autoLibrary"
    private static let lastCheckKey = "updates.lastCheck"
    private static let dismissedBuildKey = "updates.dismissedBuild"
    private static let notifiedBuildKey = "updates.notifiedBuild"
    private static let dismissedExpiryKey = "refresh.dismissed"

    private(set) var availableUpdate: SourceFeed.Version?
    private(set) var libraryUpdate: CatalogManifest?
    private(set) var installingLibrary = false
    private(set) var lastError: String?
    private(set) var refreshNotice: RefreshPolicy.Notice?

    @ObservationIgnored var onLibraryInstalled: (() -> Void)?

    private var defaults: UserDefaults { .standard }
    var isEnabled: Bool { defaults.object(forKey: Self.checkKey) as? Bool ?? true }
    var autoInstallsLibrary: Bool { defaults.object(forKey: Self.autoLibraryKey) as? Bool ?? true }

    /// An ephemeral session: no cookies, no cache, nothing persisted.
    private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.httpAdditionalHeaders = ["User-Agent": "Taima"]
        return URLSession(configuration: configuration)
    }()

    // MARK: - Daily check

    func checkIfDue(force: Bool = false) async {
        refreshExpiry()
        guard isEnabled else { return }
        if !force, let last = defaults.object(forKey: Self.lastCheckKey) as? Date, Date.now.timeIntervalSince(last) < 20 * 3600 {
            return
        }
        defaults.set(Date.now, forKey: Self.lastCheckKey)
        lastError = nil
        await checkApp()
        await checkLibrary()
    }

    private func checkApp() async {
        guard let (data, _) = try? await session.data(from: Published.sourceURL),
              let feed = try? SourceFeed.decode(data),
              let update = feed.update(for: Bundle.main.bundleIdentifier ?? "com.bjorn.taima", currentBuild: ReleaseHighlights.currentBuild)
        else { availableUpdate = nil; return }
        availableUpdate = update.build == defaults.integer(forKey: Self.dismissedBuildKey) ? nil : update
        if defaults.integer(forKey: Self.notifiedBuildKey) < update.build {
            defaults.set(update.build, forKey: Self.notifiedBuildKey)
            notify(id: "update.\(update.build)", title: "Taima \(update.version) is available",
                   body: "Open SideStore to update. Your data stays when you install over the app.")
        }
    }

    func dismissAppUpdate() {
        if let build = availableUpdate?.build { defaults.set(build, forKey: Self.dismissedBuildKey) }
        availableUpdate = nil
    }

    // MARK: - Strain library

    private func checkLibrary() async {
        guard let (data, _) = try? await session.data(from: Published.libraryURL.appending(path: "manifest.json")),
              let manifest = try? CatalogManifest.decode(data), manifest.isWellFormed,
              manifest.version > LibraryStore.installedVersion,
              (manifest.minimumBuild ?? 0) <= ReleaseHighlights.currentBuild
        else { libraryUpdate = nil; return }
        libraryUpdate = manifest
        if autoInstallsLibrary { await installLibrary() }
    }

    func installLibrary() async {
        guard let manifest = libraryUpdate, !installingLibrary else { return }
        installingLibrary = true
        defer { installingLibrary = false }
        do {
            var files: [String: Data] = [:]
            for file in manifest.files {
                let (data, _) = try await session.data(from: Published.libraryURL.appending(path: file.name))
                guard manifest.verify(data, for: file) else { throw LibraryStore.InstallError.checksum(file.name) }
                files[file.name] = data
            }
            try await Task.detached(priority: .utility) {
                try LibraryStore.install(manifest: manifest, files: files)
            }.value
            libraryUpdate = nil
            onLibraryInstalled?()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Signature expiry

    var expiry: Date? {
        Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap(EmbeddedProfile.expirationDate(in:))
    }

    /// Shows the notice in the final 48 hours and keeps one reminder
    /// scheduled for the day before.
    func refreshExpiry() {
        let expiry = self.expiry
        let notice = RefreshPolicy.notice(expiry: expiry)
        let dismissed = defaults.double(forKey: Self.dismissedExpiryKey)
        refreshNotice = (expiry.map { $0.timeIntervalSince1970 } == dismissed) ? nil : notice
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["refresh.reminder"])
        guard let fire = RefreshPolicy.reminderDate(expiry: expiry) else { return }
        let content = UNMutableNotificationContent()
        content.title = "Refresh Taima tomorrow"
        content.body = "Open SideStore and refresh, or Taima stops opening. Nothing is deleted."
        content.sound = .default
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        center.add(UNNotificationRequest(identifier: "refresh.reminder", content: content,
                                         trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)))
    }

    func dismissRefreshNotice() {
        if let expiry { defaults.set(expiry.timeIntervalSince1970, forKey: Self.dismissedExpiryKey) }
        refreshNotice = nil
    }

    private func notify(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }
}

/// A downloaded strain library in Application Support, replacing the
/// bundled one when it is newer.
enum LibraryStore {
    enum InstallError: LocalizedError {
        case checksum(String), unreadable

        var errorDescription: String? {
            switch self {
            case .checksum(let name): "A downloaded library file (\(name)) didn't match its checksum, so it wasn't installed."
            case .unreadable: "The downloaded library couldn't be read, so it wasn't installed."
            }
        }
    }

    static var folder: URL { StorePaths.folder.appending(path: "Library", directoryHint: .isDirectory) }

    static var bundledVersion: Int {
        Bundle.main.url(forResource: "catalog-version", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode([String: Int].self, from: $0)["version"] } ?? 0
    }

    static var downloadedManifest: CatalogManifest? {
        (try? Data(contentsOf: folder.appending(path: "manifest.json"))).flatMap { try? CatalogManifest.decode($0) }
    }

    static var installedVersion: Int { max(bundledVersion, downloadedManifest?.version ?? 0) }

    /// The data the catalog loads: the download when newer, else the bundle.
    nonisolated static func data(_ name: String) -> Data? {
        let downloaded = StorePaths.folder.appending(path: "Library/\(name).json")
        let bundledVersion = Bundle.main.url(forResource: "catalog-version", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode([String: Int].self, from: $0)["version"] } ?? 0
        let manifest = (try? Data(contentsOf: StorePaths.folder.appending(path: "Library/manifest.json")))
            .flatMap { try? JSONDecoder().decode(CatalogManifest.self, from: $0) }
        let build = Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") ?? 0
        // A downgraded app ignores a library made for a newer build.
        if let manifest, manifest.version > bundledVersion, (manifest.minimumBuild ?? 0) <= build,
           let data = try? Data(contentsOf: downloaded) { return data }
        return Bundle.main.url(forResource: name, withExtension: "json").flatMap { try? Data(contentsOf: $0) }
    }

    /// Checks the files load as a library, then swaps them in all at once.
    nonisolated static func install(manifest: CatalogManifest, files: [String: Data]) throws {
        let catalog = StrainCatalog(curated: files["strains-curated.json"], community: files["strains.json"])
        guard !catalog.strains.isEmpty else { throw InstallError.unreadable }
        let staging = StorePaths.folder.appending(path: "Library.staging", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: staging)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        for (name, data) in files { try data.write(to: staging.appending(path: name)) }
        try JSONEncoder().encode(manifest).write(to: staging.appending(path: "manifest.json"))
        let folder = StorePaths.folder.appending(path: "Library", directoryHint: .isDirectory)
        if FileManager.default.fileExists(atPath: folder.path) {
            // Swaps in one step; the old library stays if it fails.
            _ = try FileManager.default.replaceItemAt(folder, withItemAt: staging)
        } else {
            try FileManager.default.moveItem(at: staging, to: folder)
        }
    }
}
