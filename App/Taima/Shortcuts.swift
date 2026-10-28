import AppIntents
import TaimaCore

/// Opens Taima's camera to scan a bag.
struct ScanBagIntent: AppIntent {
    static let title: LocalizedStringResource = "Scan a bag"
    static let description = IntentDescription("Opens Taima's camera to read a bag label.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppModel.shared?.destination = .scan
        return .result()
    }
}

/// Says how much is in the stash.
struct StashLeftIntent: AppIntent {
    static let title: LocalizedStringResource = "How much is in my stash"
    static let description = IntentDescription("Tells you how many grams are left and how long that lasts.")
    /// Never answers from a locked iPhone.
    static let authenticationPolicy = IntentAuthenticationPolicy.requiresAuthentication

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let bags = (try? BagStore(url: StorePaths.database).allBags()) ?? []
        let summary = InventorySummary(bags: bags)
        let grams = summary.stashGrams.formatted(.number.precision(.fractionLength(0...1)))
        if SharedContainer.isDiscreet {
            return .result(dialog: summary.daysOfSupply.map { "About \(Int($0.rounded())) days left." } ?? "Open Taima to see the details.")
        }
        if let days = summary.daysOfSupply {
            return .result(dialog: "You have \(grams) grams, about \(Int(days.rounded())) days at your current pace.")
        }
        return .result(dialog: "You have \(grams) grams in your stash.")
    }
}

/// "Log usage" for Siri and Shortcuts. Unlike the Live Activity buttons,
/// which are a deliberate tap on your own Lock Screen, a voice request
/// requires an unlocked iPhone.
struct LogUsageShortcut: AppIntent {
    static let title: LocalizedStringResource = "Log usage"
    static let description = IntentDescription("Takes an amount from the bag you are using in Taima.")
    static let authenticationPolicy = IntentAuthenticationPolicy.requiresAuthentication

    @Parameter(title: "Grams", default: 0.25, inclusiveRange: (0.01, 50))
    var grams: Double

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$grams) grams")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: IntentDialog(stringLiteral: try await LogUseIntent.log(grams, bagID: nil)))
    }
}

struct TaimaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ScanBagIntent(), phrases: ["Scan a bag in \(.applicationName)", "Add a bag to \(.applicationName)"], shortTitle: "Scan a bag", systemImageName: "camera.viewfinder")
        AppShortcut(intent: LogUsageShortcut(), phrases: ["Log usage in \(.applicationName)", "Log a bowl in \(.applicationName)"], shortTitle: "Log usage", systemImageName: "minus.circle")
        AppShortcut(intent: StashLeftIntent(), phrases: ["How much is in my \(.applicationName) stash", "Check my stash in \(.applicationName)"], shortTitle: "Stash left", systemImageName: "bag")
    }
}
