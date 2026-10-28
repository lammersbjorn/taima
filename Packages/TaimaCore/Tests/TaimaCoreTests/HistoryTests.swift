import Foundation
import Testing
@testable import TaimaCore

@Suite struct HistoryTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
        calendar.firstWeekday = 2
        return calendar
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 20) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    @Test func monthCountsUseAndDaysWithout() {
        var bag = Bag(name: "Cali Mix", grams: 5, stock: .open)
        bag.use(0.25, at: date(2026, 10, 5))
        bag.use(0.25, at: date(2026, 10, 5, 22))
        bag.use(0.5, at: date(2026, 10, 9))
        let month = UsageMonth(bags: [bag], month: date(2026, 10, 15), now: date(2026, 10, 12), calendar: calendar)
        #expect(month.days.count == 31)
        #expect(month.days[4].grams == 0.5 && month.days[4].sessions == 2)
        #expect(month.daysWithUse == 2)
        // Tracked from the first log (5th) to today (12th): 8 days, 2 with use.
        #expect(month.daysWithoutUse == 6)
        #expect(!month.days[0].isTracked && !month.days[20].isTracked)
        // 1 October 2026 is a Thursday; Monday-first weeks leave 3 blanks.
        #expect(month.leadingBlanks == 3)
    }

    @Test func rangeRunsFromTheFirstLoggedMonth() {
        var bag = Bag(name: "Cali Mix", grams: 5, stock: .open)
        bag.use(0.25, at: date(2026, 8, 30))
        let months = UsageMonth.range(bags: [bag], now: date(2026, 10, 2), calendar: calendar)
        #expect(months.count == 3)
        #expect(UsageMonth.range(bags: [], now: date(2026, 10, 2), calendar: calendar).count == 1)
    }

    @Test func memoriesFindBagsAroundThisDate() {
        let lastYear = Bag(name: "A year ago", collectedOn: date(2025, 10, 30))
        let twoYears = Bag(name: "Two years", collectedOn: date(2024, 10, 26))
        let farOff = Bag(name: "Not now", collectedOn: date(2025, 6, 1))
        let thisYear = Bag(name: "This year", collectedOn: date(2026, 10, 27))
        let memories = OnThisDay.memories(in: [lastYear, twoYears, farOff, thisYear], now: date(2026, 10, 28), calendar: calendar)
        #expect(memories.map(\.bag.name) == ["A year ago", "Two years"])
        #expect(memories.map(\.yearsAgo) == [1, 2])
    }

    @Test func memoriesAcrossNewYear() {
        let bag = Bag(name: "New year", collectedOn: date(2025, 12, 30))
        #expect(OnThisDay.memories(in: [bag], now: date(2027, 1, 1), calendar: calendar).first?.yearsAgo == 1)
    }
}
