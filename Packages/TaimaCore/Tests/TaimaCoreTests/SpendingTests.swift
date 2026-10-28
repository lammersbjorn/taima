import Foundation
import Testing
@testable import TaimaCore

@Suite struct SpendingTests {
    @Test func shopsAndMonths() {
        var a = Bag(grams: 5, priceEuros: 50); a.shop = "Coffeeshop A"; a.shopCity = "Breda"
        var b = Bag(grams: 1, priceEuros: 8); b.shop = "coffeeshop a"
        var c = Bag(grams: 1, priceEuros: 12); c.shop = "Shop B"
        let summary = SpendingSummary(bags: [a, b, c, Bag(grams: 1)])
        #expect(summary.total == 70)
        #expect(summary.pricedBags == 3)
        #expect(summary.shops.first?.visits == 2)
        #expect(summary.shops.first?.city == "Breda")
        #expect(summary.shops.first?.pricePerGram == 9)
        #expect(summary.findings.first?.hasPrefix("Coffeeshop A has been cheapest") == true)
    }
}
