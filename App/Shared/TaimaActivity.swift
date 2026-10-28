import ActivityKit
import AppIntents
import Foundation
import TaimaCore

/// The Live Activity for the bag in use.
nonisolated struct BagActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var remaining: Double
        var usedToday: Double
        var lastUse: Date?
    }

    var bagID: String
    var name: String
    var total: Double?
    var thc: String?
    /// For preroll packs: one tap logs one preroll.
    var unitGrams: Double?
    var unitCount: Int?
    /// Discreet mode: neutral icon and words on the Lock Screen.
    var discreet = false

    var symbol: String { discreet ? "circle.hexagongrid.fill" : "leaf.fill" }

    func unitsLeft(_ remaining: Double) -> Int? {
        guard let unitGrams, unitGrams > 0 else { return nil }
        return Int((remaining / unitGrams + 0.001).rounded(.down))
    }
}

/// The amounts on the Live Activity's buttons.
nonisolated enum QuickAmounts {
    static let grams: [Double] = [0.1, 0.25, 0.5]

    static func label(_ grams: Double) -> String {
        grams.formatted(.number.precision(.fractionLength(0...2))) + " g"
    }
}

/// Logs an amount used from a bag: from the Live Activity, Siri or Shortcuts.
/// Without a bag, the current one is used.
struct LogUseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Log usage"
    /// Only for the Live Activity and widget buttons; Shortcuts and Siri use
    /// LogUsageShortcut, which requires an unlocked iPhone.
    static let isDiscoverable = false
    static let description = IntentDescription("Takes an amount from the bag you are using in Taima.")

    @Parameter(title: "Grams", default: 0.25, inclusiveRange: (0.01, 50))
    var grams: Double

    @Parameter(title: "Bag ID")
    var bagID: String?

    init() {}

    init(bagID: String, grams: Double) {
        self.bagID = bagID
        self.grams = grams
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$grams) grams")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: IntentDialog(stringLiteral: try await Self.log(grams, bagID: bagID)))
    }

    /// Logs the amount and returns what to say. Shared with the Siri shortcut.
    static func log(_ grams: Double, bagID: String?) async throws -> String {
        let id = bagID.flatMap(UUID.init(uuidString:)) ?? SharedContainer.currentBagID
        guard let id else { return String(localized: "No bag is in use. Open one in Taima first.") }
        guard let bag = try await InventoryActions.use(grams, from: id) else {
            return String(localized: "That bag is no longer in Taima.")
        }
        let discreet = SharedContainer.isDiscreet
        if bag.stock == .empty, bag.lastUse.map({ Date.now.timeIntervalSince($0) > 2 }) ?? true {
            return discreet ? String(localized: "That one is already used up.") : String(localized: "\(bag.displayName) is already empty.")
        }
        if discreet { return String(localized: "Logged.") }
        let left = bag.remaining.formatted(.number.precision(.fractionLength(0...2)))
        return String(localized: "Logged. \(left) g left in \(bag.displayName).")
    }
}

/// Logs a session like the last one: from the widget's repeat button.
struct RepeatLastIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Repeat last session"
    static let isDiscoverable = false

    @Parameter(title: "Bag ID")
    var bagID: String?

    init() {}

    init(bagID: String) { self.bagID = bagID }

    func perform() async throws -> some IntentResult {
        if let id = bagID.flatMap(UUID.init(uuidString:)) ?? SharedContainer.currentBagID {
            _ = try await InventoryActions.use(0, from: id, repeatingLast: true)
        }
        return .result()
    }
}

nonisolated enum InventoryActions {
    static let changed = Notification.Name("taima.inventoryChanged")

    /// Writes the use to the database, then updates the activity and widgets.
    static func use(_ grams: Double, from id: UUID, repeatingLast: Bool = false) async throws -> Bag? {
        // One read of the collection per tap: the before and after summaries
        // and the widget snapshot all come from it.
        let store = try BagStore(url: StorePaths.database)
        var bags = try store.allBags()
        guard let index = bags.firstIndex(where: { $0.id == id }) else { return nil }
        var bag = bags[index]
        guard bag.stock != .empty else { return bag }
        let before = InventorySummary(bags: bags)
        if repeatingLast, let last = UsageEntry.toRepeat(for: bag, in: bags) {
            bag.use(last.grams, details: last.repeated())
        } else {
            bag.use(grams)
        }
        bag.updatedAt = .now
        try store.save(bag)
        bags[index] = bag
        let after = InventorySummary(bags: bags)
        Notifier.check(before: before, after: after)
        await updateActivity(for: bag, summary: after)
        let hadThumbnail = SharedContainer.readSnapshot()?.latest?.hasThumbnail ?? false
        SharedContainer.write(WidgetSnapshot(bags: bags, hasThumbnail: hadThumbnail, currentID: SharedContainer.currentBagID))
        await MainActor.run {
            NotificationCenter.default.post(name: changed, object: nil)
        }
        return bag
    }

    static func updateActivity(for bag: Bag, summary: InventorySummary) async {
        for activity in Activity<BagActivityAttributes>.activities where activity.attributes.bagID == bag.id.uuidString {
            if bag.stock == .open {
                let state = BagActivityAttributes.ContentState(remaining: bag.remaining, usedToday: summary.usedToday, lastUse: bag.lastUse)
                await activity.update(ActivityContent(state: state, staleDate: nil))
            } else {
                let state = BagActivityAttributes.ContentState(remaining: 0, usedToday: summary.usedToday, lastUse: bag.lastUse)
                await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .after(.now.addingTimeInterval(60 * 30)))
            }
        }
    }
}

/// A wait timer after an edible: effects take 30 to 90 minutes, so the
/// Lock Screen shows how long it has been before taking more.
nonisolated struct EdibleTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var takenAt: Date
    }

    var milligrams: Double?
    var discreet = false
}

enum EdibleTimer {
    static let earliest: TimeInterval = 30 * 60
    static let latest: TimeInterval = 90 * 60

    static func start(milligrams: Double?) {
        let takenAt = Date.now
        Task {
            for activity in Activity<EdibleTimerAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            let content = ActivityContent(state: EdibleTimerAttributes.ContentState(takenAt: takenAt), staleDate: takenAt.addingTimeInterval(latest))
            if let activity = try? Activity.request(attributes: EdibleTimerAttributes(milligrams: milligrams, discreet: SharedContainer.isDiscreet), content: content) {
                // Nothing updates it later, so it ends now and stays visible
                // until two hours after the edible; the timer text keeps counting.
                await activity.end(content, dismissalPolicy: .after(takenAt.addingTimeInterval(2 * 3600)))
            }
        }
    }
}
