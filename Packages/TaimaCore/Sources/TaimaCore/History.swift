import Foundation

/// Use per day for a month calendar: grams and sessions, with days without
/// use told apart from days before anything was logged.
public struct UsageMonth: Sendable {
    public struct Day: Identifiable, Hashable, Sendable {
        public var date: Date
        public var grams: Double
        public var sessions: Int
        /// After the first log and not in the future, so "no use" means something.
        public var isTracked: Bool
        public var id: Date { date }
    }

    /// The first of the month.
    public var month: Date
    public var days: [Day]
    /// Empty cells before the 1st, so weeks start on the calendar's first weekday.
    public var leadingBlanks: Int
    public var peakGrams: Double { days.map(\.grams).max() ?? 0 }
    public var daysWithoutUse: Int { days.filter { $0.isTracked && $0.sessions == 0 }.count }
    public var daysWithUse: Int { days.filter { $0.sessions > 0 }.count }

    public init(bags: [Bag], month date: Date, now: Date = .now, calendar: Calendar = .taima) {
        let start = calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
        month = start
        let count = calendar.range(of: .day, in: .month, for: start)?.count ?? 30
        let entries = bags.flatMap(\.usage)
        let firstLog = entries.map(\.date).min().map(calendar.startOfDay)
        var grams: [Date: Double] = [:]
        var sessions: [Date: Int] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.date)
            grams[day, default: 0] += entry.grams
            sessions[day, default: 0] += 1
        }
        let today = calendar.startOfDay(for: now)
        days = (0..<count).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let tracked = firstLog.map { day >= $0 } == true && day <= today
            return Day(date: day, grams: grams[day] ?? 0, sessions: sessions[day] ?? 0, isTracked: tracked)
        }
        let weekday = calendar.component(.weekday, from: start)
        leadingBlanks = (weekday - calendar.firstWeekday + 7) % 7
    }

    /// The months that have anything logged, oldest first, ending with this month.
    public static func range(bags: [Bag], now: Date = .now, calendar: Calendar = .taima) -> [Date] {
        let thisMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        guard let first = bags.flatMap(\.usage).map(\.date).min(),
              let firstMonth = calendar.dateInterval(of: .month, for: first)?.start, firstMonth < thisMonth else { return [thisMonth] }
        var months: [Date] = []
        var month = firstMonth
        while month <= thisMonth, months.count < 120 {
            months.append(month)
            guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { break }
            month = next
        }
        return months
    }
}

/// Bags collected around this date in earlier years.
public enum OnThisDay {
    public struct Memory: Identifiable, Sendable {
        public var bag: Bag
        public var yearsAgo: Int
        public var id: UUID { bag.id }
    }

    /// Within `window` days of today's date, one or more years back.
    public static func memories(in bags: [Bag], now: Date = .now, window: Int = 3, calendar: Calendar = .taima) -> [Memory] {
        let today = calendar.startOfDay(for: now)
        return bags.compactMap { bag -> Memory? in
            let collected = calendar.startOfDay(for: bag.collectedOn)
            let years = calendar.dateComponents([.year], from: collected, to: today).year ?? 0
            for back in [years, years + 1] where back >= 1 {
                guard let anniversary = calendar.date(byAdding: .year, value: back, to: collected) else { continue }
                let distance = abs(calendar.dateComponents([.day], from: anniversary, to: today).day ?? .max)
                if distance <= window { return Memory(bag: bag, yearsAgo: back) }
            }
            return nil
        }
        .sorted { ($0.yearsAgo, $1.bag.collectedOn) < ($1.yearsAgo, $0.bag.collectedOn) }
    }
}
