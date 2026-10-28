import Foundation

/// The roulette for a session with friends: a strain from the collection, a
/// way of smoking, whose turn it is and optionally a game or house rule.
/// Everything is editable; nothing here is logged against the stash.
public struct PartySettings: Codable, Hashable, Sendable {
    public var players: [Player]
    public var ways: [SmokeWay]
    public var cards: [RuleCard]
    /// Draw a game or rule card with each spin.
    public var includesCards: Bool
    public var onlyStash: Bool
    /// Letters Bim Bam Baap deals; hard ones such as Q and X are left out by default.
    public var letters: String
    public var categories: [String]
    /// How often a legendary card is pulled, 0...1. Optional so settings
    /// saved before legendary pulls still decode.
    public var legendaryChanceSetting: Double?
    /// Which built-in deck the stored cards came from.
    public var contentRevision: Int?
    /// Deck kinds the person switched off, by name.
    public var deckKindsOff: [String]?
    /// What the roulette spins for. Optional so older settings decode; all on by default.
    public var rouletteStrainSetting: Bool?
    public var rouletteWaySetting: Bool?
    public var rouletteGameSetting: Bool?
    public var rouletteStrain: Bool { get { rouletteStrainSetting ?? true } set { rouletteStrainSetting = newValue } }
    public var rouletteWay: Bool { get { rouletteWaySetting ?? true } set { rouletteWaySetting = newValue } }
    public var rouletteGame: Bool { get { rouletteGameSetting ?? true } set { rouletteGameSetting = newValue } }
    /// Written cards played on earlier nights, so the deck doesn't repeat.
    public var seenCards: [String]?
    /// Spins since the last legendary card, for the guaranteed pull.
    public var legendaryDrought: Int?
    public var spinsSinceLegendary: Int {
        get { legendaryDrought ?? 0 }
        set { legendaryDrought = newValue }
    }
    public var legendaryChance: Double {
        get { legendaryChanceSetting ?? 1.0 / 15 }
        set { legendaryChanceSetting = min(max(newValue, 0), 1) }
    }

    public init(players: [Player] = [], ways: [SmokeWay] = SmokeWay.defaults, cards: [RuleCard] = RuleCard.defaults,
                includesCards: Bool = true, onlyStash: Bool = true,
                letters: String = "ABCDEFGHIJKLMNOPRSTUVW", categories: [String] = PartySettings.defaultCategories) {
        self.players = players
        self.ways = ways
        self.cards = cards
        self.includesCards = includesCards
        self.onlyStash = onlyStash
        self.letters = letters
        self.categories = categories
        self.contentRevision = PartyContent.shared.revision
    }

    public static let defaultCategories = [
        "Fruit", "Vegetable", "Animal", "Country", "City", "Football club", "Footballer", "Brand",
        "Film or series", "Actor", "Singer or band", "Song", "Food", "Snack", "Drink", "Job",
        "Boy's name", "Girl's name", "Something in a coffeeshop", "Strain", "Something in the kitchen",
        "Something green", "Sport", "Car brand", "Video game", "Cartoon character", "Something you take on holiday",
    ]

    /// Reads stored settings. A newer built-in deck replaces the stored
    /// built-in cards (keeping which ones are switched on), retires removed
    /// ones and adds new ones; the person's own cards are untouched.
    public static func decode(_ data: Data?) -> PartySettings {
        guard let data, var settings = try? JSONDecoder().decode(PartySettings.self, from: data) else { return PartySettings() }
        for way in SmokeWay.defaults where !settings.ways.contains(where: { $0.id == way.id }) { settings.ways.append(way) }
        let defaults = RuleCard.defaults
        if (settings.contentRevision ?? 1) < PartyContent.shared.revision {
            settings.cards = settings.cards.compactMap { card in
                guard card.builtIn else { return card }
                guard var fresh = defaults.first(where: { $0.id == card.id }) else { return nil }
                fresh.enabled = card.enabled
                return fresh
            }
            settings.contentRevision = PartyContent.shared.revision
        }
        for card in defaults where !settings.cards.contains(where: { $0.id == card.id }) { settings.cards.append(card) }
        return settings
    }

    public var encoded: Data? { try? JSONEncoder().encode(self) }
}

public struct Player: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var points: Int
    /// Times this player was the "sjaak": out of time or a wrong answer.
    public var sjaak: Int
    /// Legendary challenges taken.
    public var legendaryCount: Int?
    public var legendaries: Int {
        get { legendaryCount ?? 0 }
        set { legendaryCount = newValue }
    }

    public init(id: UUID = UUID(), name: String, points: Int = 0, sjaak: Int = 0) {
        self.id = id
        self.name = name
        self.points = points
        self.sjaak = sjaak
    }
}

public struct SmokeWay: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var symbol: String
    public var enabled: Bool
    public var builtIn: Bool

    public init(id: String = UUID().uuidString, name: String, symbol: String = "flame", enabled: Bool = true, builtIn: Bool = false) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.enabled = enabled
        self.builtIn = builtIn
    }

    public static let defaults: [SmokeWay] = [
        SmokeWay(id: "pure", name: "Pure joint", symbol: "leaf", builtIn: true),
        SmokeWay(id: "joint", name: "Joint with tobacco", symbol: "smoke", builtIn: true),
        SmokeWay(id: "blunt", name: "Blunt", symbol: "smoke.fill", builtIn: true),
        SmokeWay(id: "bong", name: "Bong", symbol: "drop", builtIn: true),
        SmokeWay(id: "pipe", name: "Pipe", symbol: "flame", builtIn: true),
        SmokeWay(id: "vape", name: "Vaporizer", symbol: "wind", builtIn: true),
        SmokeWay(id: "special", name: "Special roll: cross, tulip or twister", symbol: "sparkles", enabled: false, builtIn: true),
    ]
}

public struct RuleCard: Codable, Hashable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable { case game, rule }

    public var id: String
    public var title: String
    /// The steps, one per line.
    public var detail: String
    public var kind: Kind
    public var minPlayers: Int
    /// Holding smoke and fast rounds: marked in the app, mostly off by default.
    public var intense: Bool
    public var enabled: Bool
    public var builtIn: Bool
    /// Deals a Bim Bam Baap letter and category. Kept for stored cards; new
    /// cards use `deck`.
    public var dealsPrompt: Bool
    public var legendaryFlag: Bool?
    public var combinesWays: Bool?
    /// One line that sells the game.
    public var hook: String?
    /// Who smokes, said plainly.
    public var puff: String?
    /// The prompt deck this card deals from, by name.
    public var deckName: String?

    public var legendary: Bool {
        get { legendaryFlag ?? false }
        set { legendaryFlag = newValue }
    }
    public var dealsCombo: Bool {
        get { combinesWays ?? false }
        set { combinesWays = newValue }
    }
    public var deck: PromptDeck? {
        get { deckName.flatMap(PromptDeck.init(rawValue:)) ?? (dealsPrompt ? .letters : nil) }
        set { deckName = newValue?.rawValue; dealsPrompt = newValue == .letters }
    }
    public var steps: [String] {
        detail.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    public init(id: String = UUID().uuidString, title: String, detail: String, kind: Kind = .rule, minPlayers: Int = 1,
                intense: Bool = false, enabled: Bool = true, builtIn: Bool = false, dealsPrompt: Bool = false,
                legendary: Bool = false, dealsCombo: Bool = false, hook: String? = nil, puff: String? = nil, deck: PromptDeck? = nil) {
        self.id = id
        self.title = title
        self.detail = detail
        self.kind = kind
        self.minPlayers = minPlayers
        self.intense = intense
        self.enabled = enabled
        self.builtIn = builtIn
        self.dealsPrompt = dealsPrompt || deck == .letters
        self.legendaryFlag = legendary
        self.combinesWays = dealsCombo
        self.hook = hook
        self.puff = puff
        self.deckName = deck?.rawValue
    }

    /// The built-in deck, in English as stored.
    public static var defaults: [RuleCard] { PartyContent.shared.cards(language: "en") }
}

/// What a card deals each round: prompts in the person's language.
public enum PromptDeck: String, Codable, CaseIterable, Sendable, Identifiable {
    case letters, neverHaveIEver, wouldYouRather, mostLikely, hotSeat, debate, conspiracy, story, explain,
         actItOut, categories, rhyme, straightFace, impressions, songs, island, bingo, tableRule
    public var id: String { rawValue }

    /// Session bingo deals five at once.
    public var dealCount: Int { self == .bingo ? 5 : 1 }

    /// Only the player whose turn it is should see these.
    public var isSecret: Bool { self == .explain || self == .actItOut || self == .songs }
}

/// The built-in cards and prompt decks, English and Dutch side by side
/// (Resources/party-content.json). Stored settings keep the English text;
/// the app shows it in the person's language until they edit it.
public struct PartyContent: Sendable {
    public static let shared = PartyContent()
    public let revision: Int
    private let rawCards: [RawCard]
    private let decks: [String: [String: [String]]]
    private let translations: [String: String]

    private struct RawCard: Decodable, Sendable {
        struct Text: Decodable, Sendable { let title: String; let hook: String; let steps: [String]; let puff: String }
        let id: String, kind: String, minPlayers: Int, intense: Bool, enabled: Bool, legendary: Bool, combo: Bool
        let deck: String?
        let en: Text, nl: Text
    }
    private struct File: Decodable { let revision: Int; let cards: [RawCard]; let decks: [String: [String: [String]]] }

    init() {
        let file = Bundle.module.url(forResource: "party-content", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode(File.self, from: $0) }
        revision = file?.revision ?? 0
        rawCards = file?.cards ?? []
        decks = file?.decks ?? [:]
        var map: [String: String] = [:]
        for card in rawCards {
            map[card.en.title] = card.nl.title
            map[card.en.hook] = card.nl.hook
            map[card.en.puff] = card.nl.puff
            map[card.en.steps.joined(separator: "\n")] = card.nl.steps.joined(separator: "\n")
        }
        translations = map
    }

    /// Dutch when the core runs in Dutch, else English.
    public static var language: String {
        Bundle.module.preferredLocalizations.first?.hasPrefix("nl") == true ? "nl" : "en"
    }

    func cards(language: String) -> [RuleCard] {
        rawCards.map { raw in
            let text = language == "nl" ? raw.nl : raw.en
            return RuleCard(id: raw.id, title: text.title, detail: text.steps.joined(separator: "\n"),
                            kind: raw.kind == "rule" ? .rule : .game, minPlayers: raw.minPlayers, intense: raw.intense,
                            enabled: raw.enabled, builtIn: true, legendary: raw.legendary, dealsCombo: raw.combo,
                            hook: text.hook, puff: text.puff, deck: raw.deck.flatMap(PromptDeck.init(rawValue:)))
        }
    }

    public func prompts(_ deck: PromptDeck, language: String = PartyContent.language) -> [String] {
        decks[deck.rawValue]?[language] ?? decks[deck.rawValue]?["en"] ?? []
    }

    /// Built-in English text shown in Dutch when the app runs in Dutch.
    func translate(_ english: String) -> String? {
        Self.language == "nl" ? translations[english] : nil
    }
}

/// One spin's result.
public struct PartySpin: Hashable, Sendable {
    public var bagID: UUID?
    public var way: SmokeWay?
    public var card: RuleCard?
    public var playerID: UUID?
    public var letter: Character?
    public var category: String?
    /// Two ways to combine, for a combo pull.
    public var combo: [SmokeWay] = []
    /// What the card dealt this round, in the person's language.
    public var prompts: [String] = []
    public var isLegendary: Bool { card?.legendary == true }

    public init() {}
}

public enum PartyEngine {
    /// After this many spins without one, the next card is legendary.
    public static let legendaryPity = 20

    /// Spins the parts that are switched on. The turn moves round the table
    /// in order; everything else is random.
    public static func spin<R: RandomNumberGenerator>(_ settings: PartySettings, bags: [Bag], after previous: PartySpin?,
                                                      using rng: inout R) -> PartySpin {
        let pool = settings.onlyStash ? bags.filter { $0.stock != .empty } : bags
        var spin = PartySpin()
        spin.bagID = pool.randomElement(using: &rng)?.id
        spin.way = settings.ways.filter(\.enabled).randomElement(using: &rng)
        if !settings.players.isEmpty {
            let index = previous?.playerID.flatMap { id in settings.players.firstIndex { $0.id == id } }
            spin.playerID = settings.players[index.map { ($0 + 1) % settings.players.count } ?? 0].id
        }
        if settings.includesCards {
            let playing = max(settings.players.count, 1)
            let available = settings.cards.filter { $0.enabled && $0.minPlayers <= playing }
            let legendary = available.filter(\.legendary)
            let owed = settings.legendaryChance > 0 && settings.spinsSinceLegendary >= legendaryPity
            if !legendary.isEmpty, owed || Double.random(in: 0..<1, using: &rng) < settings.legendaryChance {
                spin.card = legendary.randomElement(using: &rng)
            } else {
                spin.card = available.filter { !$0.legendary }.randomElement(using: &rng)
            }
            if spin.card?.dealsCombo == true {
                spin.combo = combo(settings, using: &rng)
            }
            if let deck = spin.card?.deck {
                deal(deck, settings: settings, into: &spin, using: &rng)
            }
        }
        return spin
    }

    public static func spin(_ settings: PartySettings, bags: [Bag], after previous: PartySpin?) -> PartySpin {
        var rng = SystemRandomNumberGenerator()
        return spin(settings, bags: bags, after: previous, using: &rng)
    }

    /// Fresh content for the card already drawn: a new letter, question or scene.
    public static func deal<R: RandomNumberGenerator>(_ deck: PromptDeck, settings: PartySettings, into spin: inout PartySpin,
                                                      using rng: inout R) {
        if deck == .letters {
            (spin.letter, spin.category) = prompt(settings, using: &rng)
            spin.prompts = []
        } else {
            let all = PartyContent.shared.prompts(deck)
            spin.prompts = Array(all.shuffled(using: &rng).prefix(deck.dealCount))
        }
    }

    public static func deal(_ deck: PromptDeck, settings: PartySettings, into spin: inout PartySpin) {
        var rng = SystemRandomNumberGenerator()
        deal(deck, settings: settings, into: &spin, using: &rng)
    }

    /// Two different ways of smoking; from all ways when fewer than two are on.
    public static func combo<R: RandomNumberGenerator>(_ settings: PartySettings, using rng: inout R) -> [SmokeWay] {
        let enabled = settings.ways.filter(\.enabled)
        let pool = enabled.count >= 2 ? enabled : settings.ways
        return Array(pool.shuffled(using: &rng).prefix(2))
    }

    /// A Bim Bam Baap letter and category.
    public static func prompt<R: RandomNumberGenerator>(_ settings: PartySettings, using rng: inout R) -> (Character?, String?) {
        let letters = settings.letters.uppercased().filter(\.isLetter)
        return (letters.randomElement(using: &rng), settings.categories.filter { !$0.isEmpty }.randomElement(using: &rng))
    }

    public static func prompt(_ settings: PartySettings) -> (Character?, String?) {
        var rng = SystemRandomNumberGenerator()
        return prompt(settings, using: &rng)
    }
}

/// Built-in roulette text is stored in English and shown in the person's
/// language. Anything they edited or added is shown exactly as written.
public enum PartyText {
    static let builtIn: Set<String> = Set(SmokeWay.defaults.map(\.name) + PartySettings.defaultCategories)

    public static func display(_ text: String) -> String {
        if let translated = PartyContent.shared.translate(text) { return translated }
        guard builtIn.contains(text) else { return text }
        #if canImport(Darwin)
        return String(localized: String.LocalizationValue(text), bundle: .module)
        #else
        return text
        #endif
    }
}

public extension RuleCard {
    var displayTitle: String { PartyText.display(title) }
    var displayDetail: String { PartyText.display(detail) }
    var displayHook: String? { hook.map(PartyText.display) }
    var displayPuff: String? { puff.map(PartyText.display) }
    var displaySteps: [String] { displayDetail.split(separator: "\n").map(String.init).filter { !$0.isEmpty } }
}

public extension SmokeWay {
    var displayName: String { PartyText.display(name) }
}

// MARK: - The party deck

/// What kind of card the deck deals. Each reads differently and gets its
/// own colour in the app.
public enum DeckKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case challenge, duel, vote, everyone, question, dilemma, quickfire, act, debate, rule, ruleEnd, minigame, smoke, legendary
    case herd, scale, bomb, mission, missionEnd, standings
    public var id: String { rawValue }

    /// The kinds a person can switch on and off.
    public static let choosable: [DeckKind] = [.challenge, .duel, .vote, .everyone, .question, .dilemma, .herd, .scale, .bomb,
                                                .quickfire, .act, .debate, .mission, .rule, .minigame, .smoke]

    /// How often each kind comes up at each stage of the night. Easy group
    /// cards warm the room up; personal questions and duels come later.
    func weight(stage: Int) -> Int {
        switch (self, stage) {
        case (.everyone, 1), (.vote, 1), (.herd, 1): 4
        case (.dilemma, 1), (.quickfire, 1), (.challenge, 1): 3
        case (.scale, 1), (.question, 1), (.duel, 1), (.act, 1): 2
        case (.bomb, 1), (.minigame, 1), (.smoke, 1), (.debate, 1), (.rule, 1): 1
        case (.mission, 1): 0
        case (.challenge, 2): 4
        case (.duel, 2), (.vote, 2), (.question, 2), (.herd, 2), (.scale, 2), (.minigame, 2): 3
        case (.question, _), (.challenge, _): 4
        case (.duel, _), (.vote, _), (.everyone, _), (.dilemma, _), (.bomb, _), (.minigame, _): 3
        case (.ruleEnd, _), (.missionEnd, _), (.standings, _), (.legendary, _): 0
        default: 2
        }
    }

    /// Cards that pit two named people against each other.
    var needsTwo: Bool { self == .duel || self == .debate }
}

/// One card as dealt: names filled in, in the person's language.
public struct DealtCard: Hashable, Sendable, Identifiable {
    public var id = UUID()
    public var kind: DeckKind
    public var text: String
    /// The names used in `text`, so the app can highlight them.
    public var names: [String] = []
    /// Shown only to the named player: charades, missions. Shown openly when a mission is revealed.
    public var secret: String?
    public var seconds: Int?
    /// For a rule or mission: how many cards it lasts.
    public var ruleCards: Int?
    /// A mini-game or legendary card, with what it dealt.
    public var game: RuleCard?
    public var spin: PartySpin?
    public var playerID: UUID?
    public var otherID: UUID?
    /// For a scale card: its two ends and the secret spot, 1...10.
    public var scaleEnds: [String] = []
    public var target: Int?
    /// For a hot potato: when it goes off, in seconds. Never shown.
    public var fuse: Int?
}

/// Where a night is: whose turn, what came up, the rule and mission in force.
public struct DeckState: Sendable {
    public struct ActiveRule: Hashable, Sendable {
        public var text: String
        public var end: String
        public var cardsLeft: Int
    }
    public struct ActiveMission: Hashable, Sendable {
        public var playerID: UUID?
        public var name: String
        public var mission: String
        public var cardsLeft: Int
    }
    public var turn = 0
    /// Written cards already played, kept across nights so the deck doesn't repeat.
    public var seen: Set<String> = []
    public var lastKinds: [DeckKind] = []
    public var rule: ActiveRule?
    public var mission: ActiveMission?
    public var dealt = 0
    /// How often each player has been picked as the second name.
    var paired: [UUID: Int] = [:]

    public init(seen: [String]? = nil) { self.seen = Set(seen ?? []) }

    /// 1 to warm up, 2 for the middle of the night, 3 once everyone's loose.
    public var stage: Int { dealt < 8 ? 1 : dealt < 24 ? 2 : 3 }
}

public enum PartyDeck {
    struct RawCard: Decodable, Sendable {
        let id: String, kind: String, en: String, nl: String
        let level: Int?
        let seconds: Int?, secret: String?, secretNL: String?
        let ends_en: String?, ends_nl: String?, cards: Int?
    }
    private struct File: Decodable {
        let deck: [RawCard]
        let fallback: [String: [String: [String]]]
    }
    private static let file: File? = Bundle.module.url(forResource: "party-content", withExtension: "json")
        .flatMap { try? Data(contentsOf: $0) }
        .flatMap { try? JSONDecoder().decode(File.self, from: $0) }

    static var cards: [RawCard] { file?.deck ?? [] }
    public static var cardCount: Int { cards.count }

    /// Every how many cards the scores come up, when people are scoring.
    public static let standingsEvery = 15

    /// The next card of a mixed round. `interludes` adds standings and
    /// secret missions; the roulette leaves them out.
    public static func next<R: RandomNumberGenerator>(_ settings: PartySettings, bags: [Bag], state: inout DeckState,
                                                      interludes: Bool = true, using rng: inout R) -> DealtCard {
        if let ended = endRuleIfDue(&state) { return ended }
        if let revealed = endMissionIfDue(&state) { return revealed }
        let players = settings.players
        if interludes, players.count >= 2, state.dealt > 0, state.dealt.isMultiple(of: standingsEvery),
           let leader = players.max(by: { $0.points < $1.points }), leader.points > 0 {
            state.dealt += 1
            return DealtCard(kind: .standings, text: leader.name, names: [leader.name], playerID: leader.id)
        }
        let (p1, p2) = pickPlayers(players, state: &state, using: &rng)
        defer { state.dealt += 1 }

        // Legendary first: rare, or owed after a drought. Never on the first card.
        let playing = max(players.count, 1)
        let legendary = settings.cards.filter { $0.enabled && $0.legendary && $0.minPlayers <= playing }
        let owed = settings.legendaryChance > 0 && settings.spinsSinceLegendary >= PartyEngine.legendaryPity
        let recentLegendary = state.lastKinds.suffix(8).contains(.legendary)
        if !legendary.isEmpty, state.dealt > 0, !recentLegendary,
           owed || Double.random(in: 0..<1, using: &rng) < settings.legendaryChance,
           let card = legendary.randomElement(using: &rng) {
            remember(.legendary, in: &state)
            return gameCard(card, kind: .legendary, settings: settings, p1: p1, using: &rng)
        }

        let pool = bags.filter { settings.onlyStash ? $0.stock != .empty : true }
        let games = settings.cards.filter { $0.enabled && !$0.legendary && $0.kind == .game && $0.minPlayers <= playing }
        let allowed = DeckKind.choosable.filter { kind in
            guard settings.deckKindOn(kind) else { return false }
            switch kind {
            case .smoke: return !pool.isEmpty || settings.ways.contains(where: \.enabled)
            case .minigame: return !games.isEmpty
            case .rule: return state.rule == nil
            case .mission: return interludes && state.mission == nil && players.count >= 3
            default: return true
            }
        }
        // Never the same kind twice in a row, and no kind three times in six.
        let fresh = allowed.filter { kind in
            kind != state.lastKinds.last && state.lastKinds.suffix(6).filter { $0 == kind }.count < 2
        }
        let kinds = fresh.isEmpty ? allowed : fresh
        let total = kinds.map { $0.weight(stage: state.stage) }.reduce(0, +)
        guard total > 0 else {
            return DealtCard(kind: .challenge, text: String(localized: "Switch on a few kinds of cards under Customize.", bundle: .module))
        }
        var roll = Int.random(in: 0..<total, using: &rng)
        let kind = kinds.first { roll -= $0.weight(stage: state.stage); return roll < 0 } ?? .challenge
        remember(kind, in: &state)

        switch kind {
        case .minigame:
            let game = games.randomElement(using: &rng)!
            return gameCard(game, kind: .minigame, settings: settings, p1: p1, using: &rng)
        case .smoke:
            var spin = PartySpin()
            spin.bagID = pool.randomElement(using: &rng)?.id
            spin.way = settings.ways.filter(\.enabled).randomElement(using: &rng)
            spin.playerID = p1.id
            return DealtCard(kind: .smoke, text: p1.name, names: [p1.name], spin: spin, playerID: p1.id)
        default:
            guard let raw = draw(kind, state: &state, using: &rng) else { return DealtCard(kind: .challenge, text: p1.name) }
            let nl = language == "nl"
            let written = fill(nl ? raw.nl : raw.en, p1: p1, p2: p2)
            let secret = (nl ? (raw.secretNL ?? raw.secret) : raw.secret).map { fill($0, p1: p1, p2: p2) }
            var card = DealtCard(kind: kind, text: written, secret: secret, seconds: raw.seconds, playerID: p1.id, otherID: p2.id)
            switch kind {
            case .herd:
                card.text = String(localized: "On three, everyone says \(written).", bundle: .module)
            case .scale:
                card.scaleEnds = written.components(separatedBy: "|")
                card.target = Int.random(in: 1...10, using: &rng)
                card.text = String(localized: "\(p1.name), name something that sits on your secret number.", bundle: .module)
            case .bomb:
                card.fuse = Int.random(in: 20...55, using: &rng)
            case .rule:
                let end = fill(nl ? (raw.ends_nl ?? "") : (raw.ends_en ?? ""), p1: p1, p2: p2)
                card.ruleCards = raw.cards ?? 5
                state.rule = .init(text: written, end: end, cardsLeft: raw.cards ?? 5)
            case .mission:
                card.ruleCards = raw.cards ?? 8
                state.mission = .init(playerID: p1.id, name: p1.name, mission: secret ?? "", cardsLeft: raw.cards ?? 8)
            default: break
            }
            let spoken = [p1.name, p2.name].flatMap { [$0, $0.prefix(1).lowercased() + $0.dropFirst()] }
            card.names = Array(Set(spoken.filter { card.text.contains($0) || (card.secret?.contains($0) ?? false) })).sorted()
            return card
        }
    }

    public static func next(_ settings: PartySettings, bags: [Bag], state: inout DeckState) -> DealtCard {
        var rng = SystemRandomNumberGenerator()
        return next(settings, bags: bags, state: &state, using: &rng)
    }

    /// The next card when playing one game on its own.
    public static func next<R: RandomNumberGenerator>(only game: RuleCard, _ settings: PartySettings, state: inout DeckState,
                                                      using rng: inout R) -> DealtCard {
        let (p1, _) = pickPlayers(settings.players, state: &state, using: &rng)
        state.dealt += 1
        return gameCard(game, kind: game.legendary ? .legendary : .minigame, settings: settings, p1: p1, using: &rng)
    }

    public static func next(only game: RuleCard, _ settings: PartySettings, state: inout DeckState) -> DealtCard {
        var rng = SystemRandomNumberGenerator()
        return next(only: game, settings, state: &state, using: &rng)
    }

    // MARK: Helpers

    private struct Named { var id: UUID?; var name: String }

    private static var language: String { PartyContent.language }

    /// A card of this kind nobody has seen yet, preferring the stage the
    /// night is at. Once a kind is used up, it's shuffled back in.
    private static func draw<R: RandomNumberGenerator>(_ kind: DeckKind, state: inout DeckState, using rng: inout R) -> RawCard? {
        let ofKind = cards.filter { $0.kind == kind.rawValue }
        var unseen = ofKind.filter { !state.seen.contains($0.id) && ($0.level ?? 1) <= state.stage }
        if unseen.isEmpty {
            state.seen.subtract(ofKind.map(\.id))
            unseen = ofKind.filter { ($0.level ?? 1) <= state.stage }
        }
        let current = unseen.filter { ($0.level ?? 1) == state.stage }
        let pick = (!current.isEmpty && Double.random(in: 0..<1, using: &rng) < 0.6 ? current : unseen).randomElement(using: &rng)
        if let pick { state.seen.insert(pick.id) }
        return pick
    }

    private static func remember(_ kind: DeckKind, in state: inout DeckState) {
        state.lastKinds.append(kind)
        if state.lastKinds.count > 12 { state.lastKinds.removeFirst() }
    }

    /// Turns go round the table; the second name is whoever has been picked
    /// least, so nobody is left out of the duels.
    private static func pickPlayers<R: RandomNumberGenerator>(_ players: [Player], state: inout DeckState, using rng: inout R) -> (Named, Named) {
        guard !players.isEmpty else {
            let p1 = fallback("p1").randomElement(using: &rng) ?? "?"
            let p2 = fallback("p2").randomElement(using: &rng) ?? "?"
            return (Named(name: p1), Named(name: p2))
        }
        let first = players[state.turn % players.count]
        state.turn += 1
        let others = players.filter { $0.id != first.id }
        let fewest = others.map { state.paired[$0.id, default: 0] }.min() ?? 0
        let second = others.filter { state.paired[$0.id, default: 0] == fewest }.randomElement(using: &rng)
        if let second { state.paired[second.id, default: 0] += 1 }
        return (Named(id: first.id, name: first.name),
                second.map { Named(id: $0.id, name: $0.name) } ?? Named(name: fallback("p2").randomElement(using: &rng) ?? "?"))
    }

    private static func fallback(_ slot: String) -> [String] { file?.fallback[language]?[slot] ?? [] }

    /// Puts the names in. A stand-in such as "Whoever laughed last" starts
    /// lowercase when it lands mid-sentence; real names keep their case.
    private static func fill(_ text: String, p1: Named, p2: Named) -> String {
        var result = text
        for (slot, who) in [("{p1}", p1), ("{p2}", p2)] {
            while let range = result.range(of: slot) {
                let before = result[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
                let startsSentence = before.isEmpty || before.hasSuffix(".") || before.hasSuffix("!") || before.hasSuffix("?")
                let name = who.id == nil && !startsSentence ? who.name.prefix(1).lowercased() + who.name.dropFirst() : who.name
                result.replaceSubrange(range, with: name)
            }
        }
        return result
    }

    private static func gameCard<R: RandomNumberGenerator>(_ game: RuleCard, kind: DeckKind, settings: PartySettings, p1: Named,
                                                           using rng: inout R) -> DealtCard {
        var spin = PartySpin()
        spin.card = game
        spin.playerID = p1.id
        if let deck = game.deck { PartyEngine.deal(deck, settings: settings, into: &spin, using: &rng) }
        if game.dealsCombo { spin.combo = PartyEngine.combo(settings, using: &rng) }
        return DealtCard(kind: kind, text: game.displayTitle, names: [p1.name], game: game, spin: spin, playerID: p1.id)
    }

    /// A rule that has run its course deals its own ending card.
    private static func endRuleIfDue(_ state: inout DeckState) -> DealtCard? {
        guard var rule = state.rule else { return nil }
        rule.cardsLeft -= 1
        if rule.cardsLeft > 0 {
            state.rule = rule
            return nil
        }
        state.rule = nil
        return DealtCard(kind: .ruleEnd, text: rule.end)
    }

    /// A mission that has run out is revealed to everyone.
    private static func endMissionIfDue(_ state: inout DeckState) -> DealtCard? {
        guard var mission = state.mission else { return nil }
        mission.cardsLeft -= 1
        if mission.cardsLeft > 0 {
            state.mission = mission
            return nil
        }
        state.mission = nil
        return DealtCard(kind: .missionEnd, text: String(localized: "\(mission.name), the mission is over. Reveal it.", bundle: .module),
                         names: [mission.name], secret: mission.mission, playerID: mission.playerID)
    }
}

public extension PartySettings {
    /// Every kind is on unless switched off.
    func deckKindOn(_ kind: DeckKind) -> Bool { !(deckKindsOff ?? []).contains(kind.rawValue) }

    mutating func setDeckKind(_ kind: DeckKind, on: Bool) {
        var off = Set(deckKindsOff ?? [])
        if on { off.remove(kind.rawValue) } else { off.insert(kind.rawValue) }
        deckKindsOff = off.sorted()
    }
}

// MARK: - Roulette

/// One roulette spin: only the parts that are switched on.
public struct RouletteSpin: Hashable, Sendable, Identifiable {
    public var id = UUID()
    public var playerID: UUID?
    public var playerName: String?
    public var bagID: UUID?
    public var way: SmokeWay?
    /// A card from the deck, with names filled in.
    public var game: DealtCard?
}

public extension PartyDeck {
    /// Spins a strain, a way and a game, each only when switched on. The
    /// turn moves round the table as in the deck.
    static func roulette<R: RandomNumberGenerator>(_ settings: PartySettings, bags: [Bag], state: inout DeckState,
                                                   using rng: inout R) -> RouletteSpin {
        var spin = RouletteSpin()
        if settings.rouletteGame {
            // The game card brings its own turn; smoke rounds would repeat the spin.
            var deckSettings = settings
            deckSettings.setDeckKind(.smoke, on: false)
            let card = next(deckSettings, bags: bags, state: &state, interludes: false, using: &rng)
            spin.game = card
            spin.playerID = card.playerID
            spin.playerName = card.names.first
        } else if !settings.players.isEmpty {
            let player = settings.players[state.turn % settings.players.count]
            state.turn += 1
            state.dealt += 1
            spin.playerID = player.id
            spin.playerName = player.name
        } else {
            state.dealt += 1
        }
        if settings.rouletteStrain {
            let pool = settings.onlyStash ? bags.filter { $0.stock != .empty } : bags
            spin.bagID = pool.randomElement(using: &rng)?.id
        }
        if settings.rouletteWay {
            spin.way = settings.ways.filter(\.enabled).randomElement(using: &rng)
        }
        return spin
    }

    static func roulette(_ settings: PartySettings, bags: [Bag], state: inout DeckState) -> RouletteSpin {
        var rng = SystemRandomNumberGenerator()
        return roulette(settings, bags: bags, state: &state, using: &rng)
    }
}

