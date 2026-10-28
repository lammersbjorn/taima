import Foundation

/// Decides when a reminder is due. The app schedules the notification;
/// this only compares before and after a change, so each crossing fires once.
public enum ReminderRules {
    public enum Reminder: Equatable, Sendable {
        case weeklyLimitReached(limit: Double, used: Double)
        case lowStash(days: Int, grams: Double)
    }

    public static func due(before: InventorySummary, after: InventorySummary, weeklyLimit: Double?, lowStashDays: Int?) -> [Reminder] {
        var due: [Reminder] = []
        if let limit = weeklyLimit, limit > 0, before.usedThisWeek < limit, after.usedThisWeek >= limit {
            due.append(.weeklyLimitReached(limit: limit, used: after.usedThisWeek))
        }
        if let threshold = lowStashDays, let days = after.daysOfSupply, days < Double(threshold),
           (before.daysOfSupply ?? .infinity) >= Double(threshold) {
            due.append(.lowStash(days: Int(days.rounded(.down)), grams: after.stashGrams))
        }
        return due
    }
}
