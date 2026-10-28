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
    }

    public static let defaultCategories = [
        "Fruit", "Vegetable", "Animal", "Country", "City", "Football club", "Footballer", "Brand",
        "Film or series", "Actor", "Singer or band", "Song", "Food", "Snack", "Drink", "Job",
        "Boy's name", "Girl's name", "Something in a coffeeshop", "Strain", "Something in the kitchen",
        "Something green", "Sport", "Car brand", "Video game", "Cartoon character", "Something you take on holiday",
    ]

    /// Reads stored settings; new built-in cards and ways are added on update.
    public static func decode(_ data: Data?) -> PartySettings {
        guard let data, var settings = try? JSONDecoder().decode(PartySettings.self, from: data) else { return PartySettings() }
        for way in SmokeWay.defaults where !settings.ways.contains(where: { $0.id == way.id }) { settings.ways.append(way) }
        for card in RuleCard.defaults where !settings.cards.contains(where: { $0.id == card.id }) { settings.cards.append(card) }
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
    public var detail: String
    public var kind: Kind
    public var minPlayers: Int
    /// Holding smoke and fast rounds: off by default and marked in the app.
    public var intense: Bool
    public var enabled: Bool
    public var builtIn: Bool
    /// Deals a letter and a category with the card.
    public var dealsPrompt: Bool

    public init(id: String = UUID().uuidString, title: String, detail: String, kind: Kind = .rule, minPlayers: Int = 1,
                intense: Bool = false, enabled: Bool = true, builtIn: Bool = false, dealsPrompt: Bool = false) {
        self.id = id
        self.title = title
        self.detail = detail
        self.kind = kind
        self.minPlayers = minPlayers
        self.intense = intense
        self.enabled = enabled
        self.builtIn = builtIn
        self.dealsPrompt = dealsPrompt
    }

    /// Dutch session games as commonly played (jonkoroken.nl, wiet-info.nl,
    /// bimbambaas.nl), in Taima's own words. Variants that risk fainting are
    /// left out; holding games are off by default.
    public static let defaults: [RuleCard] = [
        RuleCard(id: "bimbambaap", title: "Bim Bam Baap",
                 detail: "Pim Pam Pet with a joint. Take a puff and name a word for the letter and category before you breathe out. Too slow or wrong? You're the sjaak: skip a round. A word that ends with its first letter earns a free turn.",
                 kind: .game, minPlayers: 2, builtIn: true, dealsPrompt: true),
        RuleCard(id: "onemoretime", title: "One more time",
                 detail: "House rule: spin again with the same strain and way of smoking. The next player picks up.",
                 kind: .rule, builtIn: true),
        RuleCard(id: "watzieje", title: "What do you see?",
                 detail: "In turn, name something everyone in the room can see. No body parts, no repeats. Stuck? Pass the joint on.",
                 kind: .game, minPlayers: 2, builtIn: true),
        RuleCard(id: "dierenspel", title: "Animal chain",
                 detail: "Name an animal. The next player names one starting with your last letter. Swap animals for countries, brands or films to change it up.",
                 kind: .game, minPlayers: 2, builtIn: true),
        RuleCard(id: "woordenspel", title: "Word chain",
                 detail: "Say a compound word. The next player makes a new one with one of its parts. Each part may be used twice.",
                 kind: .game, minPlayers: 2, builtIn: true),
        RuleCard(id: "vakantie", title: "I'm going on holiday",
                 detail: "Stoner edition: each player repeats the list and adds something weed-related. Forget one and the round ends.",
                 kind: .game, minPlayers: 3, builtIn: true),
        RuleCard(id: "alfabet", title: "A to Z",
                 detail: "Pick a category and go through the alphabet together, one letter each.",
                 kind: .game, minPlayers: 2, builtIn: true, dealsPrompt: true),
        RuleCard(id: "wievanons", title: "Who of us?",
                 detail: "Read out a statement, count to three and everyone points at who fits it best.",
                 kind: .game, minPlayers: 3, builtIn: true),
        RuleCard(id: "waarheid", title: "Truth or dare",
                 detail: "Mild edition: answer honestly or do a harmless dare. Anyone can pass.",
                 kind: .game, minPlayers: 2, builtIn: true),
        RuleCard(id: "trickpuff", title: "Trick puff",
                 detail: "Invent a silly way to take a puff. The others copy it; the group picks the best.",
                 kind: .game, minPlayers: 3, builtIn: true),
        RuleCard(id: "blaas", title: "Smoke ring battle",
                 detail: "Everyone blows their best smoke ring. The group votes for the winner.",
                 kind: .game, minPlayers: 2, builtIn: true),
        RuleCard(id: "jammin", title: "Jammin'",
                 detail: "Put on Bob Marley's Jammin'. Take a small puff each time you hear the word.",
                 kind: .game, minPlayers: 2, intense: true, enabled: false, builtIn: true),
        RuleCard(id: "charades", title: "Stoner charades",
                 detail: "Act out a film, song or stoner moment without words. The others guess.",
                 kind: .game, minPlayers: 4, builtIn: true),
        RuleCard(id: "raadnummer", title: "Name that tune",
                 detail: "Play a few seconds of a song. First to name it wins the round.",
                 kind: .game, minPlayers: 2, builtIn: true),
        RuleCard(id: "bingo", title: "Session bingo",
                 detail: "Everyone writes five things that might happen tonight. First to see all five calls bingo.",
                 kind: .game, minPlayers: 2, builtIn: true),
        RuleCard(id: "rollen", title: "Creative roll",
                 detail: "Try a special roll: a cross, tulip or twister. The group judges.",
                 kind: .game, minPlayers: 1, builtIn: true),
        RuleCard(id: "321", title: "3-2-1",
                 detail: "Three puffs, then two, then one, passed round; breathe out when you're ready. Intense: keep it short and sit down.",
                 kind: .game, minPlayers: 3, intense: true, enabled: false, builtIn: true),
        RuleCard(id: "maxxen", title: "Maxxen",
                 detail: "Hold a puff while the joint goes round. Intense: holding longer adds nothing but strain. Breathe out whenever you need to.",
                 kind: .game, minPlayers: 3, intense: true, enabled: false, builtIn: true),
        RuleCard(id: "pass", title: "Pass is fine",
                 detail: "Anyone can skip a round, any time. Water and a snack for the table.",
                 kind: .rule, builtIn: true),
    ]
}

/// One spin's result.
public struct PartySpin: Hashable, Sendable {
    public var bagID: UUID?
    public var way: SmokeWay?
    public var card: RuleCard?
    public var playerID: UUID?
    public var letter: Character?
    public var category: String?
}

public enum PartyEngine {
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
            spin.card = settings.cards.filter { $0.enabled && $0.minPlayers <= playing }.randomElement(using: &rng)
            if spin.card?.dealsPrompt == true {
                (spin.letter, spin.category) = prompt(settings, using: &rng)
            }
        }
        return spin
    }

    public static func spin(_ settings: PartySettings, bags: [Bag], after previous: PartySpin?) -> PartySpin {
        var rng = SystemRandomNumberGenerator()
        return spin(settings, bags: bags, after: previous, using: &rng)
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
