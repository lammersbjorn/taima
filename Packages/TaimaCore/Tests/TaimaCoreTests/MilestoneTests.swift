import Testing
@testable import TaimaCore

@Suite struct MilestoneTests {
    @Test func countsProgress() {
        var a = Bag(name: "Gelato", producer: "FYTA", strainType: .hybrid)
        a.rating10 = 8
        let b = Bag(name: "Haze", producer: "Canadelaar", form: .preroll)
        let milestones = Milestone.evaluate([a, b, Bag(name: "Gelato", producer: "Someone")])
        let byID = Dictionary(uniqueKeysWithValues: milestones.map { ($0.id, $0) })
        #expect(byID["bags.1"]?.achieved == true)
        #expect(byID["bags.10"]?.current == 3)
        #expect(byID["strains.5"]?.current == 2)
        #expect(byID["growers.3"]?.current == 2)
        #expect(byID["growers.10"]?.target == 10)
        #expect(byID["forms.all"]?.current == 2)
        #expect(byID["rated.10"]?.progress == 0.1)
    }
}
