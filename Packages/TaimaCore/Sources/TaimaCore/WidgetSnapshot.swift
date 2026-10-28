import Foundation

/// What the widgets show, written by the app into the shared App Group
/// container. Widgets never open the database.
public struct WidgetSnapshot: Codable, Sendable, Equatable {
    public struct Latest: Codable, Sendable, Equatable {
        public var id: UUID
        public var name: String
        public var producer: String?
        public var thc: String?
        public var grams: Double?
        public var collectedOn: Date
        public var hasThumbnail: Bool

        public init(id: UUID, name: String, producer: String?, thc: String?, grams: Double?, collectedOn: Date, hasThumbnail: Bool) {
            self.id = id
            self.name = name
            self.producer = producer
            self.thc = thc
            self.grams = grams
            self.collectedOn = collectedOn
            self.hasThumbnail = hasThumbnail
        }
    }

    public struct Current: Codable, Sendable, Equatable {
        public var id: UUID
        public var name: String
        public var remaining: Double
        public var total: Double?
        public var thc: String?
        /// Grams per preroll, so the widget logs one.
        public var unitGrams: Double?
        /// The last amount logged, for the widget's repeat button.
        public var lastGrams: Double?
    }

    /// Written already redacted in discreet mode, so the shared container
    /// never holds names.
    public var isDiscreet: Bool?
    public var discreet: Bool { isDiscreet ?? false }
    public var symbol: String { discreet ? "circle.hexagongrid.fill" : "leaf.fill" }
    public var stashGrams: Double = 0
    public var fullCount: Int = 0
    public var daysOfSupply: Double?
    public var usedToday: Double = 0
    public var usedThisWeek: Double = 0
    public var weeklyLimit: Double?
    public var current: Current?
    public var bagCount: Int
    public var strainCount: Int
    public var totalGrams: Double
    public var averageTHC: Double?
    public var latest: Latest?
    /// Bags per month, oldest first, for the last six months.
    public var recentMonths: [Int]
    public var updatedAt: Date

    public init(bags: [Bag], hasThumbnail: Bool, currentID: UUID? = nil, now: Date = .now, calendar: Calendar = .taima) {
        let stats = CollectionStats(bags: bags, calendar: calendar)
        let inventory = InventorySummary(bags: bags, now: now, calendar: calendar)
        stashGrams = inventory.stashGrams
        fullCount = inventory.fullCount
        daysOfSupply = inventory.daysOfSupply
        usedToday = inventory.usedToday
        usedThisWeek = inventory.usedThisWeek
        let limit = SharedContainer.defaults?.double(forKey: "limits.weeklyGrams") ?? 0
        weeklyLimit = limit > 0 ? limit : nil
        isDiscreet = SharedContainer.isDiscreet
        if let currentID, let bag = bags.first(where: { $0.id == currentID }), bag.stock == .open {
            current = Current(id: bag.id, name: bag.displayName, remaining: bag.remaining, total: bag.grams, thc: bag.thc?.label,
                              unitGrams: bag.gramsPerUnit, lastGrams: UsageEntry.toRepeat(for: bag, in: bags)?.grams)
        }
        bagCount = stats.bagCount
        strainCount = StrainGroup.group(bags).count
        totalGrams = stats.totalGrams
        averageTHC = stats.averageTHC
        if let bag = bags.max(by: { $0.collectedOn < $1.collectedOn }) {
            latest = Latest(id: bag.id, name: bag.displayName, producer: bag.producer, thc: bag.thc?.label, grams: bag.grams, collectedOn: bag.collectedOn, hasThumbnail: hasThumbnail)
        }
        let thisMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        recentMonths = (0..<6).reversed().map { back in
            let start = calendar.date(byAdding: .month, value: -back, to: thisMonth) ?? thisMonth
            return stats.months.first { $0.start == start }?.count ?? 0
        }
        updatedAt = now
        if discreet { self = redacted() }
    }

    /// The same totals with names, growers, THC and the photo removed.
    public func redacted() -> WidgetSnapshot {
        var copy = self
        copy.isDiscreet = true
        copy.latest?.name = "Latest item"
        copy.latest?.producer = nil
        copy.latest?.thc = nil
        copy.latest?.hasThumbnail = false
        copy.current?.name = "Bag in use"
        copy.current?.thc = nil
        return copy
    }

    public static let placeholder: WidgetSnapshot = {
        var snapshot = WidgetSnapshot(bags: [], hasThumbnail: false)
        snapshot.bagCount = 12
        snapshot.strainCount = 9
        snapshot.totalGrams = 41.5
        snapshot.averageTHC = 24.6
        snapshot.recentMonths = [1, 3, 2, 4, 1, 3]
        snapshot.stashGrams = 7.5
        snapshot.fullCount = 2
        snapshot.daysOfSupply = 12
        snapshot.current = Current(id: UUID(), name: "Cali Mix", remaining: 3.2, total: 5, thc: "24%")
        snapshot.latest = Latest(id: UUID(), name: "Girl Scout Cookie", producer: nil, thc: "24%", grams: 5, collectedOn: .now, hasThumbnail: false)
        return snapshot
    }()
}

/// The App Group shared with the widget extension. SideStore and AltStore
/// rename App Groups per Apple ID and list the real names under
/// `ALTAppGroups` in Info.plist, so that list wins over the built-in name.
public enum SharedContainer {
    public static let defaultGroup = "group.com.bjorn.taima"

    public static var groupIdentifier: String {
        (Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String])?.first ?? defaultGroup
    }

    public static var url: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier)
    }

    public static var defaults: UserDefaults? { UserDefaults(suiteName: groupIdentifier) }

    public static var snapshotURL: URL? { url?.appending(path: "widget.json") }
    public static var thumbnailURL: URL? { url?.appending(path: "latest-thumb.jpg") }

    public static let breakStartKey = "tbreak.start"
    public static let currentBagKey = "inventory.current"
    public static let discreetKey = "privacy.discreet"

    /// Discreet mode: widgets, the Live Activity and notifications leave
    /// strain names and photos out.
    public static var isDiscreet: Bool {
        get { defaults?.bool(forKey: discreetKey) ?? false }
        set { defaults?.set(newValue, forKey: discreetKey) }
    }

    /// The open bag the Live Activity and quick logging use.
    public static var currentBagID: UUID? {
        get { defaults?.string(forKey: currentBagKey).flatMap(UUID.init(uuidString:)) }
        set { defaults?.set(newValue?.uuidString, forKey: currentBagKey) }
    }

    public static func write(_ snapshot: WidgetSnapshot) {
        guard let url = snapshotURL, let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }

    public static func readSnapshot() -> WidgetSnapshot? {
        guard let url = snapshotURL, let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }
}

/// Where the app keeps its database. Live Activity buttons run in the app's
/// process and open the same file.
public enum StorePaths {
    public static var folder: URL {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        let folder = base.appending(path: "Taima", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    public static var database: URL { folder.appending(path: "taima.sqlite") }
    public static var photos: URL { folder.appending(path: "Photos", directoryHint: .isDirectory) }
}
