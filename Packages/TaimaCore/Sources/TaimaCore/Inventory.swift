import Foundation

public extension Bag {
    var stock: StockState {
        get { stockState ?? .empty }
        set { stockState = newValue }
    }

    var usage: [UsageEntry] {
        get { usageLog ?? [] }
        set { usageLog = newValue }
    }

    /// Grams left in the bag. A full bag holds its label weight.
    var remaining: Double {
        switch stock {
        case .empty: 0
        case .full: remainingGrams ?? grams ?? 0
        case .open: max(0, remainingGrams ?? grams ?? 0)
        }
    }

    var usedGrams: Double { usage.map(\.grams).reduce(0, +) }

    /// The most recent use; entries can be logged out of order.
    var lastUse: Date? { usage.map(\.date).max() }

    /// 0...1 of the label weight left, when the weight is known.
    var fractionLeft: Double? {
        guard let grams, grams > 0 else { return nil }
        return min(1, max(0, remaining / grams))
    }

    /// Opens a full bag so amounts can be taken from it.
    mutating func open() {
        guard stock != .open else { return }
        remainingGrams = stock == .empty ? (grams ?? 0) : remaining
        stock = .open
    }

    /// Takes an amount from the bag and logs it. Opens a full bag; a bag
    /// that reaches zero becomes empty.
    @discardableResult
    mutating func use(_ amount: Double, at date: Date = .now, details: UsageEntry? = nil) -> Double {
        // An empty bag stays empty: a late tap must not refill it.
        guard stock != .empty else { return 0 }
        if stock == .full { open() }
        let taken = min(max(0, amount), remaining)
        guard taken > 0 else { return 0 }
        var entry = details ?? UsageEntry(date: date, grams: taken)
        entry.date = date
        entry.grams = taken
        usage.append(entry)
        remainingGrams = (remaining - taken).roundedToHundredths
        // Rounding leaves crumbs ("1 g in 3 prerolls" ends at 0,01 g).
        let crumb = gramsPerUnit.map { $0 / 2 } ?? 0.01
        if remaining < crumb {
            remainingGrams = 0
            stock = .empty
        }
        return taken
    }

    /// Changes how a logged use is described, never its amount.
    mutating func updateUse(_ entry: UsageEntry) {
        guard let index = usage.firstIndex(where: { $0.id == entry.id }) else { return }
        var updated = entry
        updated.grams = usage[index].grams
        usage[index] = updated
    }

    /// Removes a logged use and puts its amount back.
    mutating func undoUse(_ id: UUID) {
        guard let entry = usage.first(where: { $0.id == id }) else { return }
        usage.removeAll { $0.id == id }
        if stock == .empty { stock = .open; remainingGrams = 0 }
        remainingGrams = min((remaining + entry.grams).roundedToHundredths, grams ?? .infinity)
    }
}

extension Double {
    var roundedToHundredths: Double { (self * 100).rounded() / 100 }
}

/// Stash totals and usage pace across the collection.
public struct InventorySummary: Sendable {
    public struct Day: Hashable, Sendable, Identifiable {
        public var date: Date
        public var grams: Double
        public var id: Date { date }
    }

    public var stashGrams: Double
    public var fullCount: Int
    public var openCount: Int
    public var usedToday: Double
    /// Since Monday 00:00 of the current week.
    public var usedThisWeek: Double
    /// Days this week, up to and including today, with nothing logged.
    public var useFreeDaysThisWeek: Int
    public var daysSoFarThisWeek: Int
    public var usedLast7Days: Double
    public var usedLast30Days: Double
    /// Grams per day over the last 30 days.
    public var dailyAverage: Double
    /// Days the stash lasts at the 30-day pace, when there is a pace.
    public var daysOfSupply: Double?
    /// Grams used per day, last 30 days, oldest first.
    public var days: [Day]

    public init(bags: [Bag], now: Date = .now, calendar: Calendar = .taima) {
        stashGrams = bags.filter { $0.stock != .empty }.map(\.remaining).reduce(0, +)
        fullCount = bags.filter { $0.stock == .full }.count
        openCount = bags.filter { $0.stock == .open }.count
        let entries = bags.flatMap(\.usage)
        let today = calendar.startOfDay(for: now)
        func used(sinceDaysAgo days: Int) -> Double {
            let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today
            return entries.filter { $0.date >= start && $0.date <= now }.map(\.grams).reduce(0, +)
        }
        usedToday = used(sinceDaysAgo: 1)
        var weekCalendar = calendar
        weekCalendar.firstWeekday = 2
        let weekStart = weekCalendar.dateInterval(of: .weekOfYear, for: now)?.start ?? today
        usedThisWeek = entries.filter { $0.date >= weekStart && $0.date <= now }.map(\.grams).reduce(0, +)
        let daysSoFar = (calendar.dateComponents([.day], from: calendar.startOfDay(for: weekStart), to: today).day ?? 0) + 1
        let usedDays = Set(entries.filter { $0.date >= weekStart && $0.date <= now }.map { calendar.startOfDay(for: $0.date) })
        daysSoFarThisWeek = daysSoFar
        useFreeDaysThisWeek = max(0, daysSoFar - usedDays.count)
        usedLast7Days = used(sinceDaysAgo: 7)
        usedLast30Days = used(sinceDaysAgo: 30)
        dailyAverage = usedLast30Days / 30
        daysOfSupply = dailyAverage > 0 ? stashGrams / dailyAverage : nil
        var totals: [Date: Double] = [:]
        for entry in entries { totals[calendar.startOfDay(for: entry.date), default: 0] += entry.grams }
        days = (0..<30).reversed().compactMap { back in
            calendar.date(byAdding: .day, value: -back, to: today).map { Day(date: $0, grams: totals[$0] ?? 0) }
        }
    }
}

public extension Bag {
    var form: ProductForm {
        get { productForm ?? .bag }
        set { productForm = newValue }
    }

    /// Grams in one preroll, when the pack's weight and count are known.
    var gramsPerUnit: Double? {
        guard form == .preroll, let grams, let unitCount, unitCount > 0 else { return nil }
        return grams / Double(unitCount)
    }

    /// Whole prerolls left.
    var unitsLeft: Int? {
        guard let per = gramsPerUnit, per > 0 else { return nil }
        return Int((remaining / per + 0.001).rounded(.down))
    }

    /// "2 of 3 prerolls" or "1,4 g", for lists and the Live Activity.
    var remainingLabel: String {
        if let left = unitsLeft, let unitCount {
            return String(localized: "\(left) of \(unitCount) prerolls", bundle: .module)
        }
        return remaining.formatted(.number.precision(.fractionLength(0...2))) + " g"
    }
}
