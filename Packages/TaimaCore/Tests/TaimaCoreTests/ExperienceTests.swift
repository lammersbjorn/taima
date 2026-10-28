import Foundation
import Testing
@testable import TaimaCore

@Suite struct ExperienceTests {
    @Test func legacyStarsBecomeTenPointScores() throws {
        var bag = Bag(rating: 3)
        #expect(bag.rating10 == 6)
        bag.rating10 = 7.3
        #expect(bag.rating10 == 7.5)
        #expect(bag.rating == nil)
        bag.rating10 = 12
        #expect(bag.rating10 == 10)
    }

    @Test func insights() {
        func bag(_ grower: String, _ thc: Double, _ score: Double, _ type: StrainType, _ effects: [String], side: [String] = []) -> Bag {
            var bag = Bag(name: "\(grower) \(thc)", producer: grower, strainType: type, thc: Potency(percent: thc))
            bag.rating10 = score
            bag.positiveEffects = effects
            bag.negativeEffects = side
            return bag
        }
        let bags = [
            bag("FYTA", 20, 6, .indica, ["Sleepy", "Relaxed"], side: ["Dry mouth"]),
            bag("FYTA", 22, 7, .indica, ["Sleepy"], side: ["dry mouth"]),
            bag("Canadelaar", 24, 8, .sativa, ["Creative"]),
            bag("Canadelaar", 26, 8.5, .sativa, ["Creative", "Happy"]),
            bag("Holigram", 28, 9.5, .hybrid, ["Happy"])
        ]
        let insights = ExperienceInsights(bags: bags)
        #expect(insights.ratedCount == 5)
        #expect(insights.averageScore == 7.8)
        #expect(insights.byGrower.first?.label == "Holigram")
        #expect(insights.negative.first == .init(name: "Dry mouth", count: 2))
        #expect((insights.thcCorrelation ?? 0) > 0.9)
        #expect(insights.findings.contains("You rate Canadelaar highest, 8,3 out of 10 over 2 bags.") || insights.findings.contains { $0.hasPrefix("You rate Canadelaar highest") })
        #expect(insights.findings.contains("Stronger bags have tended to score higher for you."))
        #expect(insights.findings.contains { $0.hasPrefix("Indica bags most often left you sleepy") })
        #expect(insights.findings.contains("Your most noted downside is dry mouth, on 2 bags."))
    }
}
