import Foundation
import Testing
@testable import TaimaCore

/// A repeatable generator for spins.
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

@Suite struct PartyTests {
    @Test func turnsGoRoundTheTable() {
        var rng = SeededGenerator(state: 1)
        let ana = Player(name: "Ana"), bo = Player(name: "Bo"), cas = Player(name: "Cas")
        let settings = PartySettings(players: [ana, bo, cas])
        var spin: PartySpin?
        var order: [UUID?] = []
        for _ in 0..<4 {
            spin = PartyEngine.spin(settings, bags: [], after: spin, using: &rng)
            order.append(spin?.playerID)
        }
        #expect(order == [ana.id, bo.id, cas.id, ana.id])
    }

    @Test func spinsOnlyWhatIsSwitchedOn() {
        var rng = SeededGenerator(state: 7)
        var settings = PartySettings(players: [Player(name: "Solo")])
        settings.ways = settings.ways.map { var way = $0; way.enabled = way.id == "bong"; return way }
        settings.onlyStash = true
        let empty = Bag(name: "Gone", stock: .empty)
        let full = Bag(name: "Here", stock: .full)
        for _ in 0..<20 {
            let spin = PartyEngine.spin(settings, bags: [empty, full], after: nil, using: &rng)
            #expect(spin.way?.id == "bong")
            #expect(spin.bagID == full.id)
            // One player: no game that needs more.
            #expect((spin.card?.minPlayers ?? 1) <= 1)
            #expect(spin.card?.intense != true)
        }
    }

    @Test func bimBamBaapDealsALetterAndCategory() {
        var rng = SeededGenerator(state: 3)
        var settings = PartySettings(players: [Player(name: "A"), Player(name: "B")], letters: "pq")
        settings.cards = settings.cards.map { var card = $0; card.enabled = card.id == "bimbambaap"; return card }
        let spin = PartyEngine.spin(settings, bags: [], after: nil, using: &rng)
        #expect(spin.card?.id == "bimbambaap")
        #expect(spin.letter == "P" || spin.letter == "Q")
        #expect(spin.category.map(PartySettings.defaultCategories.contains) == true)
    }

    @Test func noCardsWhenSwitchedOff() {
        var rng = SeededGenerator(state: 5)
        let settings = PartySettings(includesCards: false)
        #expect(PartyEngine.spin(settings, bags: [], after: nil, using: &rng).card == nil)
    }

    @Test func storedSettingsKeepEditsAndGainNewCards() throws {
        var settings = PartySettings(players: [Player(name: "Ana", points: 3)])
        settings.cards.removeAll { $0.id == "maxxen" }
        settings.cards[0].title = "Bim Bam Baas"
        settings.cards.append(RuleCard(title: "Our rule", detail: "Left hand only."))
        let restored = PartySettings.decode(settings.encoded)
        #expect(restored.players.first?.points == 3)
        #expect(restored.cards.first?.title == "Bim Bam Baas")
        #expect(restored.cards.contains { $0.title == "Our rule" })
        // A built-in card missing from storage comes back, switched off as shipped.
        #expect(restored.cards.first { $0.id == "maxxen" }?.enabled == false)
        #expect(PartySettings.decode(Data("junk".utf8)).cards.count == RuleCard.defaults.count)
    }

    @Test func intenseGamesStartSwitchedOff() {
        #expect(RuleCard.defaults.filter(\.intense).allSatisfy { !$0.enabled })
        #expect(RuleCard.defaults.contains { $0.id == "pass" && $0.enabled })
    }
}
