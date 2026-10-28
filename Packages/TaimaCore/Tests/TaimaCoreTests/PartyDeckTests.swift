import Foundation
import Testing
@testable import TaimaCore

@Suite struct PartyDeckTests {
    private func players(_ names: String...) -> [Player] { names.map { Player(name: $0) } }

    @Test func everyCardIsWrittenInBothLanguagesWithKnownPlaceholders() {
        #expect(PartyDeck.cardCount >= 150)
        for card in PartyDeck.cards {
            for text in [card.en, card.nl] {
                let leftover = text.replacingOccurrences(of: "{p1}", with: "").replacingOccurrences(of: "{p2}", with: "")
                #expect(!leftover.contains("{"), "\(card.id)")
            }
            #expect(card.en.contains("{p2}") == card.nl.contains("{p2}"), "\(card.id)")
            if card.kind == "rule" { #expect(card.ends_en != nil && card.ends_nl != nil, "\(card.id)") }
            if card.kind == "act" { #expect(card.secret != nil && card.secretNL != nil, "\(card.id)") }
        }
    }

    @Test func namesAreFilledAndTurnsRotate() {
        var rng = SeededGenerator(state: 21)
        var settings = PartySettings(players: players("Ana", "Bo", "Cas"))
        settings.legendaryChance = 0
        DeckKind.choosable.filter { $0 != .duel }.forEach { settings.setDeckKind($0, on: false) }
        var state = DeckState()
        var firsts: [UUID?] = []
        for _ in 0..<6 {
            let card = PartyDeck.next(settings, bags: [], state: &state, using: &rng)
            #expect(card.kind == .duel)
            #expect(!card.text.contains("{"))
            #expect(card.playerID != card.otherID)
            #expect(card.names.count == 2)
            firsts.append(card.playerID)
        }
        #expect(firsts == (settings.players + settings.players).map(\.id))
    }

    @Test func noPlayersStillReadsNaturally() {
        var rng = SeededGenerator(state: 2)
        var settings = PartySettings()
        settings.legendaryChance = 0
        var state = DeckState()
        for _ in 0..<40 {
            let card = PartyDeck.next(settings, bags: [], state: &state, using: &rng)
            #expect(!card.text.contains("{p"))
        }
    }

    @Test func aRuleLastsItsCardsThenEnds() {
        var rng = SeededGenerator(state: 6)
        var settings = PartySettings(players: players("Ana", "Bo"))
        settings.legendaryChance = 0
        DeckKind.choosable.filter { $0 != .rule && $0 != .vote }.forEach { settings.setDeckKind($0, on: false) }
        var state = DeckState()
        var kinds: [DeckKind] = []
        for _ in 0..<14 { kinds.append(PartyDeck.next(settings, bags: [], state: &state, using: &rng).kind) }
        let start = try! #require(kinds.firstIndex(of: .rule))
        #expect(kinds[start + 5] == .ruleEnd)
        // No second rule while one is in force.
        #expect(!kinds[(start + 1)..<(start + 5)].contains(.rule))
    }

    @Test func switchedOffKindsNeverComeUp() {
        var rng = SeededGenerator(state: 12)
        var settings = PartySettings(players: players("Ana", "Bo"))
        settings.legendaryChance = 0
        settings.setDeckKind(.duel, on: false)
        settings.setDeckKind(.minigame, on: false)
        var state = DeckState()
        for _ in 0..<200 {
            let kind = PartyDeck.next(settings, bags: [], state: &state, using: &rng).kind
            #expect(kind != .duel && kind != .minigame)
        }
    }

    @Test func singleGameModeKeepsDealingThatGame() throws {
        var rng = SeededGenerator(state: 3)
        let settings = PartySettings(players: players("Ana", "Bo"))
        let charades = try #require(settings.cards.first { $0.id == "charades" })
        var state = DeckState()
        let a = PartyDeck.next(only: charades, settings, state: &state, using: &rng)
        let b = PartyDeck.next(only: charades, settings, state: &state, using: &rng)
        #expect(a.game?.id == "charades" && b.game?.id == "charades")
        #expect(a.playerID != b.playerID)
        #expect(a.spin?.prompts.isEmpty == false)
    }
}

@Suite struct RouletteTests {
    @Test func spinsOnlyWhatIsSwitchedOn() {
        var rng = SeededGenerator(state: 5)
        var settings = PartySettings(players: [Player(name: "Ana"), Player(name: "Bo")])
        settings.rouletteGame = false
        settings.legendaryChance = 0
        let bag = Bag(name: "Cali Mix", stock: .open)
        var state = DeckState()
        let first = PartyDeck.roulette(settings, bags: [bag], state: &state, using: &rng)
        #expect(first.game == nil && first.bagID == bag.id && first.way != nil)
        #expect(first.playerName == "Ana")
        settings.rouletteStrain = false
        let second = PartyDeck.roulette(settings, bags: [bag], state: &state, using: &rng)
        #expect(second.bagID == nil && second.way != nil && second.playerName == "Bo")
    }

    @Test func aGameSpinNeverDealsASmokeRound() {
        var rng = SeededGenerator(state: 9)
        var settings = PartySettings(players: [Player(name: "Ana"), Player(name: "Bo")])
        settings.legendaryChance = 0
        var state = DeckState()
        for _ in 0..<60 {
            let spin = PartyDeck.roulette(settings, bags: [Bag(name: "X", stock: .open)], state: &state, using: &rng)
            #expect(spin.game != nil && spin.game?.kind != .smoke)
        }
    }

    @Test func olderSettingsSpinEverything() {
        let settings = PartySettings.decode(PartySettings().encoded)
        #expect(settings.rouletteStrain && settings.rouletteWay && settings.rouletteGame)
    }
}
