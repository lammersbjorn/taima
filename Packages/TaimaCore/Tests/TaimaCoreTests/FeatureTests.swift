import Foundation
import Testing
@testable import TaimaCore

@Suite struct FeatureTests {
    @Test func backFillsOnlyWhatFrontMissed() {
        var front = LabelReading()
        front.name = "Cali Mix"
        front.thc = Potency(percent: 24)
        var back = LabelReading()
        back.name = "Something else"
        back.producer = "Groene Teelt B.V."
        back.grams = 5
        back.producerKeys = ["tel:123456789"]
        let merged = front.merged(withBack: back)
        #expect(merged.name == "Cali Mix")
        #expect(merged.producer == "Groene Teelt B.V.")
        #expect(merged.grams == 5)
        #expect(merged.producerKeys == ["tel:123456789"])
    }

    @Test func backLabelGrower() {
        let lines = [
            RecognizedLine("Ingrediënten: cannabis", x: 0.1, y: 0.8, width: 0.5, height: 0.03),
            RecognizedLine("Teler: Groene Vallei B.V.", x: 0.1, y: 0.7, width: 0.5, height: 0.03),
            RecognizedLine("Postbus 12, 1234 AB Utrecht", x: 0.1, y: 0.6, width: 0.5, height: 0.03)
        ]
        #expect(LabelParser.parse(lines: lines, codes: []).producer == "Groene Vallei B.V")
        let split = [
            RecognizedLine("Geteeld door:", x: 0.1, y: 0.8, width: 0.3, height: 0.03),
            RecognizedLine("Hollandse Hoogtes", x: 0.1, y: 0.75, width: 0.3, height: 0.03)
        ]
        #expect(LabelParser.parse(lines: split, codes: []).producer == "Hollandse Hoogtes")
    }

    @Test func knownGrowerFromPhone() {
        #expect(GrowerDirectory.match(keys: ["tel:852738149"], text: "") == "Aardachtig Organics")
        #expect(GrowerDirectory.match(keys: [], text: "nothing") == nil)
    }

    @Test func groupsSameStrain() {
        let bags = [
            Bag(name: "Cali Mix", thc: Potency(percent: 24), grams: 5),
            Bag(name: "cali  mix!", thc: Potency(percent: 26), grams: 1),
            Bag(name: "Speak Special", grams: 2.5)
        ]
        let groups = StrainGroup.group(bags)
        #expect(groups.count == 2)
        #expect(groups[0].bags.count == 2)
        #expect(groups[0].totalGrams == 6)
        #expect(groups[0].averageTHC == 25)
        #expect(groups[0].thcRange == 24...26)
    }

    @Test func stashMath() {
        #expect(StashMath.thcMilligrams(grams: 1, thcPercent: 20) == 200)
        let edible = StashMath.edible(grams: 1, thcPercent: 20, efficiency: 0.5, portions: 10)
        #expect(edible.totalMilligrams == 100)
        #expect(edible.perPortionMilligrams == 10)
        #expect(StashMath.joints(grams: 0.9, perJoint: 0.3) == 3)
        #expect(StashMath.joints(grams: 1, perJoint: 0) == 0)
    }

    @Test func next420() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
        let morning = calendar.date(from: DateComponents(year: 2026, month: 10, day: 27, hour: 10))!
        let next = StashMath.next420(after: morning, calendar: calendar)
        #expect(calendar.component(.hour, from: next) == 16)
        #expect(calendar.component(.minute, from: next) == 20)
        let night = calendar.date(from: DateComponents(year: 2026, month: 10, day: 27, hour: 17))!
        #expect(calendar.component(.hour, from: StashMath.next420(after: night, calendar: calendar)) == 4)
    }

    @Test func oldRecordsDecodeWithoutBackFields() throws {
        let json = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","name":"A","collectedOn":0,"notes":"","recognizedText":"","createdAt":0,"updatedAt":0}"#
        let bag = try JSONDecoder().decode(Bag.self, from: Data(json.utf8))
        #expect(bag.backPhotoName == nil)
    }
}

@Suite struct FourTwentyDayTests {
    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 15))!
    }

    @Test func countsDaysToTheNextTwentiethOfApril() {
        #expect(StashMath.daysUntil420Day(from: day(2026, 10, 28)) == 174)
        #expect(StashMath.daysUntil420Day(from: day(2027, 4, 19)) == 1)
        #expect(StashMath.daysUntil420Day(from: day(2027, 4, 20)) == 0)
        #expect(StashMath.daysUntil420Day(from: day(2027, 4, 21)) == 365)
        #expect(StashMath.daysUntil420Day(from: day(2028, 1, 1)) == 110)
    }
}
