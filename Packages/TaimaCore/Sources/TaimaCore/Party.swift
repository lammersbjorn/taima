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
        return String(localized: String.LocalizationValue(text), bundle: .module)
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
