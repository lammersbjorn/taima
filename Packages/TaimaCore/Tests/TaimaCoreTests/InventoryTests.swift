import Foundation
import Testing
@testable import TaimaCore

@Suite struct InventoryTests {
    @Test func usingOpensAndEmpties() {
        var bag = Bag(name: "Cali Mix", grams: 1, stock: .full)
        #expect(bag.remaining == 1)
        #expect(bag.use(0.3) == 0.3)
        #expect(bag.stock == .open)
        #expect(bag.remaining == 0.7)
        #expect(bag.use(5) == 0.7)
        #expect(bag.stock == .empty)
        #expect(bag.remaining == 0)
        #expect(bag.usedGrams == 1)
    }

    @Test func undoPutsAmountBack() {
        var bag = Bag(grams: 1, stock: .full)
        bag.use(1)
        let id = bag.usage[0].id
        bag.undoUse(id)
        #expect(bag.stock == .open)
        #expect(bag.remaining == 1)
        #expect(bag.usage.isEmpty)
    }

    @Test func oldRecordsAreEmptyBags() throws {
        let json = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","name":"A","grams":5,"collectedOn":0,"notes":"","recognizedText":"","createdAt":0,"updatedAt":0}"#
        let bag = try JSONDecoder().decode(Bag.self, from: Data(json.utf8))
        #expect(bag.stock == .empty)
        #expect(bag.remaining == 0)
    }

    @Test func summary() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var open = Bag(grams: 5, stock: .full)
        open.use(1, at: now.addingTimeInterval(-3600))
        open.use(2, at: now.addingTimeInterval(-86_400 * 10))
        let full = Bag(grams: 1, stock: .full)
        let empty = Bag(grams: 5)
        let summary = InventorySummary(bags: [open, full, empty], now: now)
        #expect(summary.stashGrams == 3)
        #expect(summary.fullCount == 1)
        #expect(summary.openCount == 1)
        #expect(summary.usedLast7Days == 1)
        #expect(summary.usedLast30Days == 3)
        #expect(summary.dailyAverage == 0.1)
        #expect(summary.daysOfSupply.map { ($0 * 10).rounded() / 10 } == 30)
        #expect(summary.days.count == 30)
    }
}

@Suite struct FormTests {
    @Test func prerollPackFromLabel() {
        let lines = [
            RecognizedLine("Amnesia Pre-Rolls", x: 0.2, y: 0.7, width: 0.5, height: 0.06),
            RecognizedLine("3 x 0,5 g", x: 0.2, y: 0.6, width: 0.2, height: 0.03),
            RecognizedLine("THC 22%", x: 0.2, y: 0.55, width: 0.2, height: 0.03)
        ]
        let reading = LabelParser.parse(lines: lines, codes: [])
        #expect(reading.form == .preroll)
        #expect(reading.unitCount == 3)
        #expect(reading.grams == 1.5)
    }

    @Test func jarFromLabel() {
        let lines = [RecognizedLine("Lemon Haze potje 2 gram", x: 0.2, y: 0.7, width: 0.5, height: 0.05)]
        let reading = LabelParser.parse(lines: lines, codes: [])
        #expect(reading.form == .jar)
        #expect(reading.unitCount == nil)
    }

    @Test func prerollInventory() {
        var pack = Bag(grams: 1.5, stock: .full, form: .preroll, unitCount: 3)
        #expect(pack.gramsPerUnit == 0.5)
        #expect(pack.unitsLeft == 3)
        pack.use(pack.gramsPerUnit!)
        #expect(pack.unitsLeft == 2)
        #expect(pack.remainingLabel == "2 of 3 prerolls")
    }

    @Test func bagsStayBags() {
        let reading = LabelParser.parse(lines: Fixtures.caliMix.lines, codes: Fixtures.caliMix.codes)
        #expect(reading.form == nil)
        #expect(reading.grams == 5)
    }
}

@Suite struct InventoryEdgeTests {
    @Test func emptyBagIsNotRefilled() {
        var bag = Bag(grams: 1, stock: .full)
        bag.use(1)
        #expect(bag.use(0.5) == 0)
        #expect(bag.stock == .empty)
        #expect(bag.usage.count == 1)
    }

    @Test func prerollPackEmptiesDespiteRounding() {
        var pack = Bag(grams: 1, stock: .full, form: .preroll, unitCount: 3)
        for _ in 0..<3 { pack.use(pack.gramsPerUnit!) }
        #expect(pack.stock == .empty)
        #expect(pack.unitsLeft == 0)
    }

    @Test func undoNeverExceedsLabelWeight() {
        var bag = Bag(grams: 1, stock: .full)
        bag.use(0.5)
        bag.remainingGrams = 0.9
        bag.undoUse(bag.usage[0].id)
        #expect(bag.remaining == 1)
    }
}

@Suite struct GrowerAndHashTests {
    @Test func hashFromLabel() {
        let lines = [RecognizedLine("CO G Hasj HQ", x: 0.2, y: 0.7, width: 0.4, height: 0.06),
                     RecognizedLine("THC 30%", x: 0.2, y: 0.6, width: 0.2, height: 0.03)]
        let reading = LabelParser.parse(lines: lines, codes: [])
        #expect(reading.form == .hash)
        #expect(reading.producer == "Canadelaar")
    }

    @Test func allTenGrowers() {
        #expect(GrowerDirectory.known.count == 10)
        #expect(GrowerDirectory.match(keys: [], text: "Leli Holland B.V.") == "Village Farms Netherlands")
        #expect(GrowerDirectory.match(keys: [], text: "geteeld door Q-Farms") == "Q-Farms")
        #expect(GrowerDirectory.match(keys: [], text: "The Plug Amnesia") == "Linsboer (The Plug)")
    }
}

@Test func gtinCheckDigits() {
    for ean in ["8721098003880", "8721098004528", "8721098002081", "8721098003774"] {
        #expect(LabelParser.isValidGTIN(ean))
    }
    #expect(!LabelParser.isValidGTIN("8721098003881"))
    #expect(!LabelParser.isValidGTIN("12345"))
}
