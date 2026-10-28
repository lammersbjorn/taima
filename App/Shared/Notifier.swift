import Foundation
import TaimaCore
import UserNotifications

/// Local reminders for the weekly limit and a low stash. Nothing leaves the
/// phone; in discreet mode the text never names cannabis.
nonisolated enum Notifier {
    static let weeklyLimitKey = "limits.weeklyGrams"
    static let lowStashKey = "limits.lowStashDays"

    static var weeklyLimit: Double? {
        let value = SharedContainer.defaults?.double(forKey: weeklyLimitKey) ?? 0
        return value > 0 ? value : nil
    }

    static var lowStashDays: Int? {
        let value = SharedContainer.defaults?.integer(forKey: lowStashKey) ?? 0
        return value > 0 ? value : nil
    }

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Compares the stash before and after a change and posts what is due.
    static func check(before: InventorySummary, after: InventorySummary) {
        for reminder in ReminderRules.due(before: before, after: after, weeklyLimit: weeklyLimit, lowStashDays: lowStashDays) {
            post(reminder)
        }
    }

    private static func post(_ reminder: ReminderRules.Reminder) {
        // With the Face ID lock on, the Lock Screen shouldn't show amounts either.
        let discreet = SharedContainer.isDiscreet || UserDefaults.standard.bool(forKey: "privacy.lock")
        let content = UNMutableNotificationContent()
        switch reminder {
        case .weeklyLimitReached(let limit, let used):
            content.title = discreet ? String(localized: "Weekly goal reached") : String(localized: "Weekly limit reached")
            content.body = discreet
                ? String(localized: "You've reached the goal you set for this week.")
                : String(localized: "You've used \(format(used)) g of your \(format(limit)) g for this week.")
        case .lowStash(let days, let grams):
            content.title = discreet ? String(localized: "Running low") : String(localized: "Stash running low")
            content.body = discreet
                ? String(localized: "About \(days) days left at your current pace.")
                : String(localized: "\(format(grams)) g left, about \(days) days at your current pace.")
        }
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}
