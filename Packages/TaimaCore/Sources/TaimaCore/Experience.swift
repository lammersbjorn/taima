import Foundation

/// How a bag was experienced: a score and tags, all recorded by the person.
public extension Bag {
    /// The score out of 10; older 1–5 star ratings count double.
    var rating10: Double? {
        get { score ?? rating.map { Double($0) * 2 } }
        set {
            score = newValue.map { min(10, max(0, ($0 * 2).rounded() / 2)) }
            rating = nil
        }
    }

    var positiveEffects: [String] {
        get { effects ?? [] }
        set { effects = newValue.isEmpty ? nil : newValue }
    }

    var negativeEffects: [String] {
        get { sideEffects ?? [] }
        set { sideEffects = newValue.isEmpty ? nil : newValue }
    }

    var flavorTags: [String] {
        get { flavors ?? [] }
        set { flavors = newValue.isEmpty ? nil : newValue }
    }
}

/// Suggested tags. People can add their own; these only speed up entry.
public enum ExperienceTags {
    public static let positive = [
        "Relaxed", "Happy", "Euphoric", "Uplifted", "Creative", "Focused", "Giggly",
        "Energetic", "Talkative", "Sleepy", "Hungry", "Calm", "Tingly", "Aroused"
    ]
    public static let negative = [
        "Dry mouth", "Dry eyes", "Paranoid", "Anxious", "Dizzy", "Headache",
        "Couch-lock", "Foggy", "Racing heart", "Restless", "Drowsy next day"
    ]
    public static let flavors = [
        "Earthy", "Sweet", "Citrus", "Lemon", "Pine", "Woody", "Herbal", "Spicy",
        "Pepper", "Diesel", "Skunk", "Cheese", "Berry", "Grape", "Tropical",
        "Mint", "Vanilla", "Flowery", "Sour", "Gassy"
    ]

    /// Translate only the display value. Unknown, user-written tags stay as entered.
    public static func label(for storedValue: String) -> String {
        switch storedValue.lowercased() {
        case "relaxed": String(localized: "Relaxed", bundle: .taimaLocalization)
        case "happy": String(localized: "Happy", bundle: .taimaLocalization)
        case "euphoric": String(localized: "Euphoric", bundle: .taimaLocalization)
        case "uplifted": String(localized: "Uplifted", bundle: .taimaLocalization)
        case "creative": String(localized: "Creative", bundle: .taimaLocalization)
        case "focused": String(localized: "Focused", bundle: .taimaLocalization)
        case "giggly": String(localized: "Giggly", bundle: .taimaLocalization)
        case "energetic": String(localized: "Energetic", bundle: .taimaLocalization)
        case "talkative": String(localized: "Talkative", bundle: .taimaLocalization)
        case "sleepy": String(localized: "Sleepy", bundle: .taimaLocalization)
        case "hungry": String(localized: "Hungry", bundle: .taimaLocalization)
        case "calm": String(localized: "Calm", bundle: .taimaLocalization)
        case "tingly": String(localized: "Tingly", bundle: .taimaLocalization)
        case "aroused": String(localized: "Aroused", bundle: .taimaLocalization)
        case "dry mouth": String(localized: "Dry mouth", bundle: .taimaLocalization)
        case "dry eyes": String(localized: "Dry eyes", bundle: .taimaLocalization)
        case "paranoid": String(localized: "Paranoid", bundle: .taimaLocalization)
        case "anxious": String(localized: "Anxious", bundle: .taimaLocalization)
        case "dizzy": String(localized: "Dizzy", bundle: .taimaLocalization)
        case "headache": String(localized: "Headache", bundle: .taimaLocalization)
        case "couch-lock": String(localized: "Couch-lock", bundle: .taimaLocalization)
        case "foggy": String(localized: "Foggy", bundle: .taimaLocalization)
        case "racing heart": String(localized: "Racing heart", bundle: .taimaLocalization)
        case "restless": String(localized: "Restless", bundle: .taimaLocalization)
        case "drowsy next day": String(localized: "Drowsy next day", bundle: .taimaLocalization)
        case "earthy": String(localized: "Earthy", bundle: .taimaLocalization)
        case "sweet": String(localized: "Sweet", bundle: .taimaLocalization)
        case "citrus": String(localized: "Citrus", bundle: .taimaLocalization)
        case "lemon": String(localized: "Lemon", bundle: .taimaLocalization)
        case "pine": String(localized: "Pine", bundle: .taimaLocalization)
        case "woody": String(localized: "Woody", bundle: .taimaLocalization)
        case "herbal": String(localized: "Herbal", bundle: .taimaLocalization)
        case "spicy": String(localized: "Spicy", bundle: .taimaLocalization)
        case "pepper": String(localized: "Pepper", bundle: .taimaLocalization)
        case "diesel": String(localized: "Diesel", bundle: .taimaLocalization)
        case "skunk": String(localized: "Skunk", bundle: .taimaLocalization)
        case "cheese": String(localized: "Cheese", bundle: .taimaLocalization)
        case "berry": String(localized: "Berry", bundle: .taimaLocalization)
        case "grape": String(localized: "Grape", bundle: .taimaLocalization)
        case "tropical": String(localized: "Tropical", bundle: .taimaLocalization)
        case "mint": String(localized: "Mint", bundle: .taimaLocalization)
        case "vanilla": String(localized: "Vanilla", bundle: .taimaLocalization)
        case "flowery": String(localized: "Flowery", bundle: .taimaLocalization)
        case "sour": String(localized: "Sour", bundle: .taimaLocalization)
        case "gassy": String(localized: "Gassy", bundle: .taimaLocalization)
        case "sativa-leaning": String(localized: "Sativa-leaning", bundle: .taimaLocalization)
        case "indica-leaning": String(localized: "Indica-leaning", bundle: .taimaLocalization)
        case "balanced hybrid": String(localized: "Balanced hybrid", bundle: .taimaLocalization)
        case "mostly sativa": String(localized: "Mostly sativa", bundle: .taimaLocalization)
        case "mostly indica": String(localized: "Mostly indica", bundle: .taimaLocalization)
        case "sativa dominant": String(localized: "Sativa dominant", bundle: .taimaLocalization)
        case "indica dominant": String(localized: "Indica dominant", bundle: .taimaLocalization)
        case "myrcene": String(localized: "Myrcene", bundle: .taimaLocalization)
        case "limonene": String(localized: "Limonene", bundle: .taimaLocalization)
        case "caryophyllene": String(localized: "Caryophyllene", bundle: .taimaLocalization)
        case "pinene": String(localized: "Pinene", bundle: .taimaLocalization)
        case "linalool": String(localized: "Linalool", bundle: .taimaLocalization)
        case "humulene": String(localized: "Humulene", bundle: .taimaLocalization)
        case "terpinolene": String(localized: "Terpinolene", bundle: .taimaLocalization)
        case "ocimene": String(localized: "Ocimene", bundle: .taimaLocalization)
        case "leaning varies in breeder text": String(localized: "Leaning varies in breeder text", bundle: .taimaLocalization)
        case "afghan landrace": String(localized: "Afghan landrace", bundle: .taimaLocalization)
        case "balanced": String(localized: "Balanced", bundle: .taimaLocalization)
        case "leaning varies by breeder": String(localized: "Leaning varies by breeder", bundle: .taimaLocalization)
        case "sativa-leaning; south african origin": String(localized: "Sativa-leaning; South African origin", bundle: .taimaLocalization)
        case "balanced to indica-leaning": String(localized: "Balanced to indica-leaning", bundle: .taimaLocalization)
        case "hindu kush mountains landrace": String(localized: "Hindu Kush mountains landrace", bundle: .taimaLocalization)
        case "ammonia": String(localized: "Ammonia", bundle: .taimaLocalization)
        case "apple": String(localized: "Apple", bundle: .taimaLocalization)
        case "blueberry": String(localized: "Blueberry", bundle: .taimaLocalization)
        case "coffee": String(localized: "Coffee", bundle: .taimaLocalization)
        case "honey": String(localized: "Honey", bundle: .taimaLocalization)
        case "horny": String(localized: "Horny", bundle: .taimaLocalization)
        case "lavender": String(localized: "Lavender", bundle: .taimaLocalization)
        case "lime": String(localized: "Lime", bundle: .taimaLocalization)
        case "mango": String(localized: "Mango", bundle: .taimaLocalization)
        case "orange": String(localized: "Orange", bundle: .taimaLocalization)
        case "pineapple": String(localized: "Pineapple", bundle: .taimaLocalization)
        case "rose": String(localized: "Rose", bundle: .taimaLocalization)
        case "strawberry": String(localized: "Strawberry", bundle: .taimaLocalization)
        default: storedValue
        }
    }
}

/// Counts and plain-language findings from recorded scores and tags. Every
/// line describes the person's own records; none is advice.
public struct ExperienceInsights: Sendable {
    public struct Tag: Hashable, Sendable, Identifiable {
        public var name: String
        public var count: Int
        public var id: String { name }
    }

    public struct Average: Hashable, Sendable, Identifiable {
        public var label: String
        public var score: Double
        public var count: Int
        public var id: String { label }
    }

    public struct Point: Hashable, Sendable, Identifiable {
        public var id: UUID
        public var name: String
        public var thc: Double
        public var score: Double
    }

    public var ratedCount: Int
    public var averageScore: Double?
    public var positive: [Tag]
    public var negative: [Tag]
    public var flavors: [Tag]
    public var byGrower: [Average]
    public var byType: [Average]
    public var topStrains: [Average]
    public var thcVersusScore: [Point]
    /// Pearson correlation of THC and score, with at least five rated bags.
    public var thcCorrelation: Double?
    public var findings: [String]

    public init(bags: [Bag]) {
        let rated = bags.filter { $0.rating10 != nil }
        ratedCount = rated.count
        averageScore = rated.isEmpty ? nil : rated.compactMap(\.rating10).reduce(0, +) / Double(rated.count)

        func tally(_ tags: (Bag) -> [String]) -> [Tag] {
            var counts: [String: (name: String, count: Int)] = [:]
            for bag in bags {
                for tag in Set(tags(bag).map { $0.trimmingCharacters(in: .whitespaces) }) where !tag.isEmpty {
                    let key = tag.lowercased()
                    counts[key] = (counts[key]?.name ?? tag, (counts[key]?.count ?? 0) + 1)
                }
            }
            return counts.values.map { Tag(name: $0.name, count: $0.count) }
                .sorted { ($0.count, $1.name) > ($1.count, $0.name) }
        }
        positive = tally(\.positiveEffects)
        negative = tally(\.negativeEffects)
        flavors = tally(\.flavorTags)

        func averages(_ key: (Bag) -> String?) -> [Average] {
            var groups: [String: [Double]] = [:]
            for bag in rated {
                guard let label = key(bag), !label.isEmpty, let score = bag.rating10 else { continue }
                groups[label, default: []].append(score)
            }
            return groups.map { Average(label: $0.key, score: $0.value.reduce(0, +) / Double($0.value.count), count: $0.value.count) }
                .sorted { ($0.score, $0.count) > ($1.score, $1.count) }
        }
        byGrower = averages(\.producer)
        byType = averages { $0.strainType?.label }
        topStrains = Array(averages(\.displayName).prefix(5))

        // Flower only: hash THC is on another scale and would fake a trend.
        thcVersusScore = rated.filter(\.form.isFlower).compactMap { bag in
            guard let thc = bag.thc?.percent, let score = bag.rating10 else { return nil }
            return Point(id: bag.id, name: bag.displayName, thc: thc, score: score)
        }
        thcCorrelation = Self.correlation(thcVersusScore.map { ($0.thc, $0.score) })

        var findings: [String] = []
        if let best = byGrower.first(where: { $0.count >= 2 }) {
            let forms = Set(rated.filter { $0.producer == best.label }.map(\.form))
            findings.append(String(localized: "You rate \(best.label) highest, \(Self.format(best.score)) out of 10 over \(ItemCount.label(count: best.count, forms: forms)).", bundle: .taimaLocalization))
        }
        if let r = thcCorrelation {
            if r > 0.4 {
                findings.append(String(localized: "Stronger flower has tended to score higher for you.", bundle: .taimaLocalization))
            } else if r < -0.4 {
                findings.append(String(localized: "Stronger flower has tended to score lower for you.", bundle: .taimaLocalization))
            } else {
                findings.append(String(localized: "THC percentage hasn't predicted your scores so far.", bundle: .taimaLocalization))
            }
        }
        for type in StrainType.allCases {
            let typed = bags.filter { $0.strainType == type }
            guard typed.count >= 2 else { continue }
            var counts: [String: Int] = [:]
            for bag in typed { for tag in Set(bag.positiveEffects) { counts[tag, default: 0] += 1 } }
            if let top = counts.max(by: { ($0.value, $1.key) < ($1.value, $0.key) }), top.value >= 2 {
                findings.append(String(localized: "\(type.label) strains most often left you \(ExperienceTags.label(for: top.key).lowercased()) (\(top.value) of \(typed.count)).", bundle: .taimaLocalization))
            }
        }
        if let side = negative.first, side.count >= 2 {
            findings.append(String(localized: "Your most noted downside is \(ExperienceTags.label(for: side.name).lowercased()), on \(ItemCount.label(count: side.count, forms: Set(bags.map(\.form)))).", bundle: .taimaLocalization))
        }
        if let flavor = flavors.first, flavor.count >= 2 {
            findings.append(String(localized: "\(ExperienceTags.label(for: flavor.name)) is the flavour you note most.", bundle: .taimaLocalization))
        }
        self.findings = findings
    }

    static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }

    static func correlation(_ pairs: [(Double, Double)]) -> Double? {
        guard pairs.count >= 5 else { return nil }
        let n = Double(pairs.count)
        let meanX = pairs.map(\.0).reduce(0, +) / n
        let meanY = pairs.map(\.1).reduce(0, +) / n
        var covariance = 0.0, varianceX = 0.0, varianceY = 0.0
        for (x, y) in pairs {
            covariance += (x - meanX) * (y - meanY)
            varianceX += (x - meanX) * (x - meanX)
            varianceY += (y - meanY) * (y - meanY)
        }
        guard varianceX > 0, varianceY > 0 else { return nil }
        return covariance / (varianceX * varianceY).squareRoot()
    }
}
