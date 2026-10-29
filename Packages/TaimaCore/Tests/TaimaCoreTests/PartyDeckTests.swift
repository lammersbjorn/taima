import Foundation
import Testing
@testable import TaimaCore

@Suite struct PartyDeckTests {
    private func players(_ names: String...) -> [Player] { names.map { Player(name: $0) } }

    @Test func everyCardIsWrittenInBothLanguagesWithKnownPlaceholders() {
        #expect(PartyDeck.cardCount >= 300)
        for card in PartyDeck.cards {
            for text in [card.en, card.nl] {
                let leftover = text.replacingOccurrences(of: "{p1}", with: "").replacingOccurrences(of: "{p2}", with: "")
                #expect(!leftover.contains("{"), "\(card.id)")
            }
            #expect(card.en.contains("{p2}") == card.nl.contains("{p2}"), "\(card.id)")
            if card.kind == "rule" { #expect(card.ends_en != nil && card.ends_nl != nil, "\(card.id)") }
            if card.kind == "act" || card.kind == "mission" { #expect(card.secret != nil && card.secretNL != nil, "\(card.id)") }
            if card.kind == "scale" { #expect(card.en.split(separator: "|").count == 2 && card.nl.split(separator: "|").count == 2, "\(card.id)") }
            #expect((1...3).contains(card.level ?? 0), "\(card.id)")
            #expect(DeckKind(rawValue: card.kind) != nil, "\(card.id)")
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

    @Test func aRuleLastsItsCardsThenEnds() throws {
        var rng = SeededGenerator(state: 6)
        var settings = PartySettings(players: players("Ana", "Bo"))
        settings.legendaryChance = 0
        DeckKind.choosable.filter { $0 != .rule && $0 != .vote }.forEach { settings.setDeckKind($0, on: false) }
        var state = DeckState()
        var cards: [DealtCard] = []
        for _ in 0..<30 { cards.append(PartyDeck.next(settings, bags: [], state: &state, using: &rng)) }
        let start = try #require(cards.firstIndex { $0.kind == .rule })
        let length = try #require(cards[start].ruleCards)
        #expect(cards[start + length].kind == .ruleEnd)
        // No second rule while one is in force.
        #expect(!cards[(start + 1)..<(start + length)].contains { $0.kind == .rule })
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

@Suite struct PartyFlowTests {
    private func settings(_ names: String...) -> PartySettings {
        var settings = PartySettings(players: names.map { Player(name: $0) })
        settings.legendaryChance = 0
        settings.setDeckKind(.minigame, on: false)
        settings.setDeckKind(.smoke, on: false)
        return settings
    }

    @Test func noKindComesUpTwiceInARow() {
        var rng = SeededGenerator(state: 31)
        let settings = settings("Ana", "Bo", "Cas")
        var state = DeckState()
        var previous: DeckKind?
        for _ in 0..<300 {
            let kind = PartyDeck.next(settings, bags: [], state: &state, using: &rng).kind
            if [.ruleEnd, .missionEnd, .standings].contains(kind) { continue }
            #expect(kind != previous)
            previous = kind
        }
    }

    @Test func theNightWarmsUpBeforeItGetsPersonal() {
        var rng = SeededGenerator(state: 8)
        let settings = settings("Ana", "Bo")
        var state = DeckState()
        for _ in 0..<8 { _ = PartyDeck.next(settings, bags: [], state: &state, using: &rng) }
        // Every written card dealt in the warm-up is a level 1 card.
        let levels = state.seen.compactMap { id in PartyDeck.cards.first { $0.id == id }?.level }
        #expect(!levels.isEmpty && levels.allSatisfy { $0 == 1 })
        #expect(state.stage == 2)
    }

    @Test func cardsDontRepeatUntilTheirKindIsUsedUp() {
        var rng = SeededGenerator(state: 4)
        var settings = settings("Ana", "Bo")
        DeckKind.choosable.filter { $0 != .vote && $0 != .question }.forEach { settings.setDeckKind($0, on: false) }
        var state = DeckState()
        state.dealt = 40
        var texts: [String] = []
        for _ in 0..<30 {
            let card = PartyDeck.next(settings, bags: [], state: &state, using: &rng)
            if card.kind == .vote { texts.append(card.text) }
        }
        #expect(Set(texts).count == texts.count)
    }

    @Test func seenCardsCarryOverToTheNextNight() {
        var rng = SeededGenerator(state: 14)
        let settings = settings("Ana", "Bo")
        var first = DeckState()
        for _ in 0..<20 { _ = PartyDeck.next(settings, bags: [], state: &first, using: &rng) }
        var second = DeckState(seen: Array(first.seen))
        for _ in 0..<20 {
            let before = second.seen
            _ = PartyDeck.next(settings, bags: [], state: &second, using: &rng)
            let added = second.seen.subtracting(before)
            #expect(added.isDisjoint(with: first.seen))
        }
    }

    @Test func aMissionIsRevealedToEveryoneLater() throws {
        var rng = SeededGenerator(state: 19)
        var settings = settings("Ana", "Bo", "Cas")
        DeckKind.choosable.filter { $0 != .mission && $0 != .vote && $0 != .herd }.forEach { settings.setDeckKind($0, on: false) }
        var state = DeckState()
        state.dealt = 10
        var cards: [DealtCard] = []
        for _ in 0..<30 { cards.append(PartyDeck.next(settings, bags: [], state: &state, using: &rng)) }
        let start = try #require(cards.firstIndex { $0.kind == .mission })
        let mission = cards[start]
        #expect(mission.secret?.contains("{") == false)
        let reveal = try #require(cards[(start + 1)...].first { $0.kind == .missionEnd })
        #expect(reveal.secret == mission.secret && reveal.playerID == mission.playerID)
    }

    @Test func missionsNeedThreePlayers() {
        var rng = SeededGenerator(state: 2)
        let settings = settings("Ana", "Bo")
        var state = DeckState()
        for _ in 0..<200 { #expect(PartyDeck.next(settings, bags: [], state: &state, using: &rng).kind != .mission) }
    }

    @Test func scaleAndHotPotatoCardsCarryTheirSecrets() {
        var rng = SeededGenerator(state: 23)
        var settings = settings("Ana", "Bo")
        DeckKind.choosable.filter { $0 != .scale && $0 != .bomb }.forEach { settings.setDeckKind($0, on: false) }
        var state = DeckState()
        for _ in 0..<20 {
            let card = PartyDeck.next(settings, bags: [], state: &state, using: &rng)
            if card.kind == .scale {
                #expect(card.scaleEnds.count == 2 && (1...10).contains(card.target ?? 0))
            } else {
                #expect(card.kind == .bomb && (20...55).contains(card.fuse ?? 0))
            }
        }
    }

    @Test func standingsComeUpOnceSomeoneScores() {
        var rng = SeededGenerator(state: 6)
        var settings = settings("Ana", "Bo")
        settings.players[1].points = 3
        var state = DeckState()
        var standings: [DealtCard] = []
        for _ in 0..<40 {
            let card = PartyDeck.next(settings, bags: [], state: &state, using: &rng)
            if card.kind == .standings { standings.append(card) }
        }
        #expect(standings.count == 2)
        #expect(standings.first?.names == ["Bo"])
    }

    @Test func standInNamesAreLowercaseMidSentence() {
        var rng = SeededGenerator(state: 5)
        var settings = PartySettings()
        settings.legendaryChance = 0
        DeckKind.choosable.filter { $0 != .quickfire }.forEach { settings.setDeckKind($0, on: false) }
        var state = DeckState()
        for _ in 0..<30 {
            let card = PartyDeck.next(settings, bags: [], state: &state, using: &rng)
            #expect(!card.text.contains(": Whoever") && !card.text.contains("from Whoever") && !card.text.contains("From Whoever"))
            #expect(!card.names.isEmpty)
        }
    }

    @Test func legendariesNeverComeBackToBack() {
        var rng = SeededGenerator(state: 17)
        var settings = settings("Ana", "Bo")
        settings.legendaryChance = 0.5
        var state = DeckState()
        var kinds: [DeckKind] = []
        for _ in 0..<200 { kinds.append(PartyDeck.next(settings, bags: [], state: &state, using: &rng).kind) }
        let spots = kinds.indices.filter { kinds[$0] == .legendary }
        #expect(spots.count > 3)
        #expect(zip(spots, spots.dropFirst()).allSatisfy { $1 - $0 > 8 })
    }

    @Test func everyoneGetsPairedFairly() {
        var rng = SeededGenerator(state: 3)
        var settings = settings("Ana", "Bo", "Cas", "Dee")
        DeckKind.choosable.filter { $0 != .duel }.forEach { settings.setDeckKind($0, on: false) }
        var state = DeckState()
        var counts: [UUID: Int] = [:]
        for _ in 0..<40 {
            let card = PartyDeck.next(settings, bags: [], state: &state, using: &rng)
            if let other = card.otherID { counts[other, default: 0] += 1 }
        }
        #expect((counts.values.max() ?? 0) - (counts.values.min() ?? 0) <= 2)
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

@Suite struct WayPairingTests {
    private func bag(_ form: ProductForm, grams: Double? = 5, left: Double? = nil) -> Bag {
        var bag = Bag(name: form.rawValue, grams: grams, stock: left == nil ? .full : .open)
        bag.form = form
        bag.remainingGrams = left
        return bag
    }

    @Test func hashIsNeverRolledPure() {
        var rng = SeededGenerator(state: 1)
        let settings = PartySettings()
        for _ in 0..<200 {
            let pick = PartyEngine.pair(settings, bags: [bag(.hash)], item: true, way: true, using: &rng)
            #expect(pick.way != nil)
            #expect(!["pure", "blunt", "special", "preroll", "dab"].contains(pick.way?.id ?? ""))
        }
    }

    @Test func aPureJointNeedsEnoughFlower() {
        var rng = SeededGenerator(state: 2)
        let settings = PartySettings()
        let low = bag(.bag, left: 0.5)
        for _ in 0..<200 {
            let pick = PartyEngine.pair(settings, bags: [low], item: true, way: true, using: &rng)
            #expect(pick.way?.id != "pure" && pick.way?.id != "blunt")
        }
        let plenty = bag(.bag, left: 0.8)
        let ways = Set((0..<200).compactMap { _ in PartyEngine.pair(settings, bags: [plenty], item: true, way: true, using: &rng).way?.id })
        #expect(ways.contains("pure"))
    }

    @Test func ediblesAreNeverSpun() {
        var rng = SeededGenerator(state: 3)
        let settings = PartySettings()
        for _ in 0..<50 {
            #expect(PartyEngine.pair(settings, bags: [bag(.edible, grams: 10)], item: true, way: true, using: &rng).bag == nil)
        }
    }

    @Test func eachItemGetsAFittingWay() {
        var rng = SeededGenerator(state: 4)
        let settings = PartySettings()
        let bags = [bag(.preroll), bag(.rosin, grams: 1), bag(.jar)]
        for _ in 0..<200 {
            let pick = PartyEngine.pair(settings, bags: bags, item: true, way: true, using: &rng)
            let item = try! #require(pick.bag)
            #expect(pick.way?.suits(item) == true)
            if item.form == .preroll { #expect(pick.way?.id == "preroll") }
        }
    }

    @Test func storedBuiltInWaysLearnTheirKinds() {
        var old = PartySettings()
        old.ways = old.ways.map { var way = $0; way.forms = nil; way.minGrams = nil; return way }
        old.ways[0].enabled = false
        let settings = PartySettings.decode(old.encoded)
        let pure = settings.ways.first { $0.id == "pure" }
        #expect(pure?.minGrams == 0.8 && pure?.enabled == false)
        #expect(settings.ways.contains { $0.id == "dab" })
    }
}

@Suite struct EdibleTests {
    @Test func ediblesStayOutOfGramTotals() {
        var cookie = Bag(name: "Cookies", grams: 10, stock: .open)
        cookie.form = .edible
        cookie.remainingGrams = 10
        _ = cookie.use(1)
        let flower = Bag(name: "Haze", grams: 5, stock: .full)
        let summary = InventorySummary(bags: [cookie, flower])
        #expect(summary.stashGrams == 5)
        #expect(summary.usedThisWeek == 0)
        #expect(cookie.remaining == 9)
        #expect(CollectionStats(bags: [cookie, flower]).totalGrams == 5)
    }

    @Test func methodsFollowTheItem() {
        #expect(ConsumptionMethod.suiting(.edible).contains(.edible))
        #expect(!ConsumptionMethod.suiting(.edible).contains(.joint))
        #expect(ConsumptionMethod.suiting(.rosin).contains(.dab))
        #expect(!ConsumptionMethod.suiting(.bag).contains(.dab))
    }
}

@Suite struct EdibleCSVTests {
    @Test func thcPerPieceRoundTripsThroughCSV() throws {
        var cookie = Bag(name: "Space cookie", grams: 10, stock: .full)
        cookie.form = .edible
        cookie.thcMilligrams = 7.5
        let flower = Bag(name: "Haze", grams: 5, stock: .full)
        let csv = CSVExport.make([cookie, flower])
        #expect(csv.split(separator: "\n").first?.hasSuffix(",thc_mg_each") == true)
        let back = CSVExport.parse(csv)
        let edible = try #require(back.first { $0.name == "Space cookie" })
        #expect(edible.form == .edible && edible.thcMilligrams == 7.5 && edible.grams == 10)
        #expect(back.first { $0.name == "Haze" }?.thcMilligrams == nil)
    }

    @Test func olderCSVWithoutTheColumnStillImports() {
        let csv = "name,form,grams\nOld bag,Bag,5\n"
        let bags = CSVExport.parse(csv)
        #expect(bags.count == 1 && bags[0].thcMilligrams == nil && bags[0].grams == 5)
    }
}
