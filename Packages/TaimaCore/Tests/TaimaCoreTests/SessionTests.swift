import Foundation
import Testing
@testable import TaimaCore

@Suite struct SessionTests {
    @Test func detailedUseKeepsDetailsAndAmount() {
        var bag = Bag(grams: 1, stock: .full)
        bag.use(0.3, details: UsageEntry(grams: 99, method: .vape, moodBefore: 2, moodAfter: 4, note: "after work"))
        let entry = bag.usage[0]
        #expect(entry.grams == 0.3)
        #expect(entry.method == .vape)
        #expect(entry.moodChange == 2)
        var edited = entry
        edited.grams = 5
        edited.note = "changed"
        bag.updateUse(edited)
        #expect(bag.usage[0].grams == 0.3)
        #expect(bag.usage[0].note == "changed")
    }

    @Test func oldEntriesDecode() throws {
        let entry = try JSONDecoder().decode(UsageEntry.self, from: Data(#"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","date":0,"grams":0.25}"#.utf8))
        #expect(entry.method == nil)
    }

    @Test func insights() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
        func at(_ day: Int, _ hour: Int) -> Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))! }
        var a = Bag(name: "Gelato", grams: 5, stock: .full)
        var b = Bag(name: "Haze", grams: 5, stock: .full)
        a.use(0.4, at: at(20, 21), details: UsageEntry(grams: 0, method: .joint, moodBefore: 2, moodAfter: 4))
        a.use(0.4, at: at(21, 22), details: UsageEntry(grams: 0, method: .joint, moodBefore: 3, moodAfter: 5))
        b.use(0.1, at: at(22, 20), details: UsageEntry(grams: 0, method: .vape, moodBefore: 3, moodAfter: 3))
        b.use(0.1, at: at(23, 23), details: UsageEntry(grams: 0, method: .vape, moodBefore: 3, moodAfter: 4))
        b.use(0.2, at: at(24, 14))
        let insights = SessionInsights(bags: [a, b], calendar: calendar)
        #expect(insights.sessionCount == 5)
        #expect(insights.byHour[21] == 1)
        #expect(insights.methods.first?.label == "Joint")
        #expect(insights.findings.contains("Most of your sessions are in the evening (80%)."))
        #expect(insights.findings.contains("Gelato lifted your mood most, +2 on average over 2 sessions."))
        #expect(insights.findings.contains { $0.hasPrefix("A joint session uses") && $0.contains("a vape session") })
    }
}
