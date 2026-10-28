import Foundation
import Testing
@testable import TaimaCore

@Suite struct ReminderTests {
    @Test func weeklyLimitFiresOnceWhenCrossed() {
        var bag = Bag(grams: 5, stock: .full)
        bag.use(0.8)
        let before = InventorySummary(bags: [bag])
        bag.use(0.3)
        let after = InventorySummary(bags: [bag])
        #expect(ReminderRules.due(before: before, after: after, weeklyLimit: 1, lowStashDays: nil) == [.weeklyLimitReached(limit: 1, used: after.usedThisWeek)])
        bag.use(0.1)
        let later = InventorySummary(bags: [bag])
        #expect(ReminderRules.due(before: after, after: later, weeklyLimit: 1, lowStashDays: nil).isEmpty)
    }

    @Test func lowStashFiresWhenDropping() {
        var bag = Bag(grams: 1, stock: .full)
        for day in 1...10 { bag.use(0.05, at: Date.now.addingTimeInterval(Double(-day) * 86_400)) }
        let before = InventorySummary(bags: [bag])
        bag.use(0.35)
        let after = InventorySummary(bags: [bag])
        #expect((before.daysOfSupply ?? 0) >= 7)
        #expect(ReminderRules.due(before: before, after: after, weeklyLimit: nil, lowStashDays: 7).count == 1)
    }
}
