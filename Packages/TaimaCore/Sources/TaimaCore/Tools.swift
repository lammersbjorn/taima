import Foundation

/// Arithmetic for the tools tab. Every output is an estimate from label
/// values; real potency and absorption vary.
public enum StashMath {
    /// Milligrams of THC in an amount of flower at a label percentage.
    public static func thcMilligrams(grams: Double, thcPercent: Double) -> Double {
        max(0, grams) * 1000 * max(0, thcPercent) / 100
    }

    public struct EdibleEstimate: Equatable, Sendable {
        public var totalMilligrams: Double
        public var perPortionMilligrams: Double
    }

    /// Infused butter or oil: flower THC times how much survives
    /// decarboxylation and infusion, split into portions.
    public static func edible(grams: Double, thcPercent: Double, efficiency: Double, portions: Int) -> EdibleEstimate {
        let total = thcMilligrams(grams: grams, thcPercent: thcPercent) * min(max(efficiency, 0), 1)
        return EdibleEstimate(totalMilligrams: total, perPortionMilligrams: total / Double(max(portions, 1)))
    }

    /// Whole joints an amount of flower rolls.
    public static func joints(grams: Double, perJoint: Double) -> Int {
        guard perJoint > 0 else { return 0 }
        return Int((max(0, grams) / perJoint + 1e-9).rounded(.down))
    }

    /// The next 4:20, morning or afternoon, after `date`.
    public static func next420(after date: Date, calendar: Calendar = .current) -> Date {
        let candidates = [4, 16].compactMap { hour in
            calendar.nextDate(after: date, matching: DateComponents(hour: hour, minute: 20, second: 0), matchingPolicy: .nextTime)
        }
        return candidates.min() ?? date
    }

    /// Whole days until the next 20 April; 0 on the day itself.
    public static func daysUntil420Day(from date: Date, calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: date)
        let parts = calendar.dateComponents([.month, .day], from: today)
        if parts.month == 4, parts.day == 20 { return 0 }
        guard let next = calendar.nextDate(after: today, matching: DateComponents(month: 4, day: 20), matchingPolicy: .nextTime) else { return 0 }
        return calendar.dateComponents([.day], from: today, to: next).day ?? 0
    }

    /// Whole days since a tolerance break started.
    public static func breakDays(since start: Date, now: Date = .now, calendar: Calendar = .current) -> Int {
        max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: now)).day ?? 0)
    }
}
