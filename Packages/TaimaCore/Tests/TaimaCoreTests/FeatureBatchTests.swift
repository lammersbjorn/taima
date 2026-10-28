import Foundation
import Testing
@testable import TaimaCore

@Suite struct FeatureBatchTests {
    @Test func csvRoundTrip() {
        var bag = Bag(name: "Cali, \"Mix\"", producer: "FYTA", strainType: .sativa, thc: Potency(percent: 24.5), cbd: Potency(percent: 1, isUpperBound: true), grams: 5, priceEuros: 50, notes: "line one\nline two")
        bag.rating10 = 7.5
        bag.positiveEffects = ["Happy", "Calm"]
        bag.shop = "Shop"
        bag.form = .jar
        let parsed = CSVExport.parse(CSVExport.make([bag]))
        #expect(parsed.count == 1)
        let back = parsed[0]
        #expect(back.name == bag.name)
        #expect(back.producer == "FYTA" && back.strainType == .sativa && back.form == .jar)
        #expect(back.thc == Potency(percent: 24.5) && back.cbd == Potency(percent: 1, isUpperBound: true))
        #expect(back.grams == 5 && back.priceEuros == 50 && back.rating10 == 7.5)
        #expect(back.positiveEffects == ["Happy", "Calm"] && back.shop == "Shop")
        #expect(back.notes == "line one\nline two")
    }

    @Test func spreadsheetWithOtherColumns() {
        let csv = "Name,Grams,Rating,Colour\nGelato,1,4,green\n,2,3,blue\n"
        let bags = CSVExport.parse(csv)
        #expect(bags.map(\.name) == ["Gelato"])
        #expect(bags[0].rating10 == 8)
    }

    @Test func selfCheckScoring() {
        #expect(SelfCheck.questions.count == 8)
        #expect(SelfCheck.score([4, 1, 0, 0, 1, 0, 0, 0]) == 6)
        #expect(SelfCheck.score([4, 4, 4, 4, 4, 4, 4, 2]) == 32)
        #expect(SelfCheck.summary(for: 6).contains("lower range"))
        #expect(SelfCheck.summary(for: 12).contains("not a diagnosis"))
    }

    @Test func breakSavings() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let record = BreakRecord(start: start, end: start.addingTimeInterval(86_400 * 10))
        #expect(record.days() == 10)
        let savings = record.savings(dailyGrams: 0.3, pricePerGram: 10)
        #expect(abs(savings.grams - 3) < 0.001)
        #expect(abs((savings.euros ?? 0) - 30) < 0.001)
    }

    @Test func useFreeDaysAndYearReview() {
        var bag = Bag(name: "A", grams: 5, stock: .full)
        bag.use(0.2)
        let summary = InventorySummary(bags: [bag])
        #expect(summary.useFreeDaysThisWeek == summary.daysSoFarThisWeek - 1)
        var rated = Bag(name: "Best", producer: "FYTA", grams: 1)
        rated.rating10 = 9
        let year = Calendar.taima.component(.year, from: .now)
        let review = YearReview(bags: [bag, rated], year: year)
        #expect(review.bagCount == 2)
        #expect(review.favourite?.name == "Best")
        #expect(review.topGrower == "FYTA")
    }

    @Test func useFirstIsOldestPackDate() {
        let old = Bag(name: "Old", packedOn: Date(timeIntervalSince1970: 1_700_000_000))
        let new = Bag(name: "New", packedOn: Date(timeIntervalSince1970: 1_800_000_000))
        #expect([new, Bag(name: "Unknown"), old].useFirstOrder.map(\.name) == ["Old", "New", "Unknown"])
    }

    @Test func tobaccoShareAndTimeOfDay() {
        var bag = Bag(name: "A", thc: Potency(percent: 25), grams: 5, stock: .full)
        for index in 0..<4 {
            bag.use(0.1, details: UsageEntry(grams: 0, method: .joint, moodBefore: 2, moodAfter: 4, withTobacco: index < 3))
        }
        let insights = SessionInsights(bags: [bag])
        #expect(insights.tobaccoShare == 0.75)
        #expect(insights.liftByTHC.first?.label == "24% THC or more")
    }
}

@Test func excelDutchCSV() {
    let csv = "\u{FEFF}Name;Grams;THC\r\nGelato;1,5;24%\r\n"
    let bags = CSVExport.parse(csv)
    #expect(bags.map(\.name) == ["Gelato"])
    #expect(bags.first?.grams == 1.5)
}
