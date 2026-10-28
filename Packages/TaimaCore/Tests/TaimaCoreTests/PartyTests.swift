import Foundation
import Testing
@testable import TaimaCore

/// A repeatable generator for spins.
struct SeededGenerator: RandomNumberGenerator {
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
            // Only a rare legendary pull is intense by default.
            #expect(spin.card?.intense != true || spin.isLegendary)
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
        // Holding games are off unless asked for; One more time was asked for.
        #expect(RuleCard.defaults.filter { $0.intense && !$0.legendary && $0.id != "onemoretime" }.allSatisfy { !$0.enabled })
        #expect(RuleCard.defaults.first { $0.id == "onemoretime" }?.kind == .game)
        // Every built-in card says who smokes and how to play.
        #expect(RuleCard.defaults.allSatisfy { $0.puff?.isEmpty == false && !$0.steps.isEmpty && $0.hook?.isEmpty == false })
    }
}

@Suite struct LegendaryPullTests {
    @Test func legendaryCardsAreRareAndSeparate() {
        var rng = SeededGenerator(state: 11)
        let settings = PartySettings(players: [Player(name: "A"), Player(name: "B")])
        var legendary = 0
        for _ in 0..<3000 where PartyEngine.spin(settings, bags: [], after: nil, using: &rng).isLegendary { legendary += 1 }
        // About 1 in 15, within a generous margin.
        #expect((120...280).contains(legendary))
    }

    @Test func comboDealsTwoDifferentWays() {
        var rng = SeededGenerator(state: 2)
        var settings = PartySettings(players: [Player(name: "A")])
        settings.legendaryChance = 1
        settings.cards = settings.cards.map { var card = $0; card.enabled = card.id == "legend.combo"; return card }
        for _ in 0..<20 {
            let spin = PartyEngine.spin(settings, bags: [], after: nil, using: &rng)
            #expect(spin.card?.id == "legend.combo")
            #expect(spin.combo.count == 2 && spin.combo[0].id != spin.combo[1].id)
        }
    }

    @Test func noLegendaryWhenTheChanceIsZero() {
        var rng = SeededGenerator(state: 9)
        var settings = PartySettings(players: [Player(name: "A"), Player(name: "B")])
        settings.legendaryChance = 0
        for _ in 0..<500 { #expect(!PartyEngine.spin(settings, bags: [], after: nil, using: &rng).isLegendary) }
    }

    @Test func settingsFromBeforeLegendaryPullsStillLoad() throws {
        // Stored without the legendary fields, as build 9's first version wrote them.
        var old = PartySettings(players: [Player(name: "Ana", points: 2)])
        old.cards = old.cards.filter { !$0.id.hasPrefix("legend.") }.map { var card = $0; card.legendaryFlag = nil; card.combinesWays = nil; return card }
        old.legendaryChanceSetting = nil
        let restored = PartySettings.decode(old.encoded)
        #expect(restored.players.first?.points == 2)
        #expect(restored.cards.contains { $0.id == "legend.combo" && $0.legendary })
        #expect(abs(restored.legendaryChance - 1.0 / 15) < 0.0001)
    }
}

@Suite struct DeckTests {
    @Test func everyDeckHasPromptsInBothLanguages() {
        for deck in PromptDeck.allCases where deck != .letters {
            let english = PartyContent.shared.prompts(deck, language: "en")
            let dutch = PartyContent.shared.prompts(deck, language: "nl")
            #expect(english.count >= 8, "\(deck)")
            #expect(english.count == dutch.count, "\(deck)")
        }
        #expect(RuleCard.defaults.compactMap(\.deck).allSatisfy { $0 == .letters || !PartyContent.shared.prompts($0).isEmpty })
    }

    @Test func cardsDealFreshContent() {
        var rng = SeededGenerator(state: 4)
        var settings = PartySettings(players: [Player(name: "A"), Player(name: "B"), Player(name: "C")])
        settings.cards = settings.cards.map { var card = $0; card.enabled = card.id == "bingo"; return card }
        settings.legendaryChance = 0
        var spin = PartyEngine.spin(settings, bags: [], after: nil, using: &rng)
        #expect(spin.card?.id == "bingo")
        #expect(spin.prompts.count == 5 && Set(spin.prompts).count == 5)
        let first = spin.prompts
        PartyEngine.deal(.bingo, settings: settings, into: &spin, using: &rng)
        #expect(spin.prompts != first)
    }

    @Test func aLegendaryIsGuaranteedAfterADrought() {
        var rng = SeededGenerator(state: 8)
        var settings = PartySettings(players: [Player(name: "A"), Player(name: "B")])
        settings.legendaryChance = 0.0001
        settings.spinsSinceLegendary = PartyEngine.legendaryPity
        #expect(PartyEngine.spin(settings, bags: [], after: nil, using: &rng).isLegendary)
        settings.legendaryChance = 0
        #expect(!PartyEngine.spin(settings, bags: [], after: nil, using: &rng).isLegendary)
    }

    @Test func aNewDeckReplacesOldBuiltInCardsButKeepsOwnOnes() throws {
        var old = PartySettings()
        old.contentRevision = 1
        old.cards = [
            RuleCard(id: "bimbambaap", title: "Old title", detail: "Old text", kind: .game, enabled: false, builtIn: true, dealsPrompt: true),
            RuleCard(id: "pass", title: "Pass is fine", detail: "Retired", builtIn: true),
            RuleCard(title: "Our rule", detail: "Left hand only."),
        ]
        let restored = PartySettings.decode(old.encoded)
        let bim = try #require(restored.cards.first { $0.id == "bimbambaap" })
        #expect(bim.title == "Bim Bam Baap" && bim.hook != nil && !bim.enabled)
        #expect(!restored.cards.contains { $0.id == "pass" })
        #expect(restored.cards.contains { $0.title == "Our rule" })
        #expect(restored.cards.contains { $0.id == "neverhave" })
        #expect(restored.contentRevision == PartyContent.shared.revision)
    }
}

