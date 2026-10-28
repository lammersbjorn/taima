import Foundation

/// A cannabinoid share as printed on a label. Labels print CBD as "<1%",
/// which is an upper bound, not a measured value.
public struct Potency: Codable, Hashable, Sendable {
    public var percent: Double
    public var isUpperBound: Bool
    /// For a printed range, `percent` is the upper end.
    public var lowerBound: Double?
    public enum Basis: String, Codable, Sendable { case thca, totalTHC }
    public var basis: Basis?

    public init(percent: Double, isUpperBound: Bool = false, lowerBound: Double? = nil, basis: Basis? = nil) {
        self.percent = percent
        self.isUpperBound = isUpperBound
        self.lowerBound = lowerBound
        self.basis = basis
    }

    public var label: String {
        let number = percent.formatted(.number.precision(.fractionLength(0...1)))
        let lower = lowerBound.map { $0.formatted(.number.precision(.fractionLength(0...1))) + "–" } ?? ""
        return (isUpperBound ? "<" : "") + lower + number + "%"
    }
}

/// What the product is: flower in a bag or jar, prerolled joints, or hash.
public enum ProductForm: String, Codable, CaseIterable, Sendable, Identifiable {
    case bag, preroll, jar, hash, rosin, edible

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .bag: String(localized: "Bag", bundle: .taimaLocalization)
        case .preroll: String(localized: "Prerolls", bundle: .taimaLocalization)
        case .jar: String(localized: "Jar", bundle: .taimaLocalization)
        case .hash: String(localized: "Hash", bundle: .taimaLocalization)
        case .rosin: String(localized: "Rosin", bundle: .taimaLocalization)
        case .edible: String(localized: "Edibles", bundle: .taimaLocalization)
        }
    }

    /// Stable English CSV vocabulary, independent of the display language.
    var exportLabel: String {
        switch self {
        case .bag: "Bag"
        case .preroll: "Prerolls"
        case .jar: "Jar"
        case .hash: "Hash"
        case .rosin: "Rosin"
        case .edible: "Edibles"
        }
    }

    /// One item: "bag", "preroll pack", "jar", "piece of hash".
    public var noun: String {
        switch self {
        case .bag: String(localized: "bag", bundle: .taimaLocalization)
        case .preroll: String(localized: "preroll pack", bundle: .taimaLocalization)
        case .jar: String(localized: "jar", bundle: .taimaLocalization)
        case .hash: String(localized: "piece of hash", bundle: .taimaLocalization)
        case .rosin: String(localized: "pot of rosin", bundle: .taimaLocalization)
        case .edible: String(localized: "pack of edibles", bundle: .taimaLocalization)
        }
    }

    /// "1 jar", "3 preroll packs", with each language's plural rules.
    public func counted(_ count: Int) -> String {
        #if !canImport(Darwin)
        let nouns: (String, String) = switch self {
        case .bag: ("bag", "bags")
        case .preroll: ("preroll pack", "preroll packs")
        case .jar: ("jar", "jars")
        case .hash: ("piece of hash", "pieces of hash")
        case .rosin: ("pot of rosin", "pots of rosin")
        case .edible: ("pack of edibles", "packs of edibles")
        }
        return "\(count) \(count == 1 ? nouns.0 : nouns.1)"
        #else
        switch self {
        case .bag: String(localized: "\(count) bags", bundle: .taimaLocalization)
        case .preroll: String(localized: "\(count) preroll packs", bundle: .taimaLocalization)
        case .jar: String(localized: "\(count) jars", bundle: .taimaLocalization)
        case .hash: String(localized: "\(count) pieces of hash", bundle: .taimaLocalization)
        case .rosin: String(localized: "\(count) pots of rosin", bundle: .taimaLocalization)
        case .edible: String(localized: "\(count) packs of edibles", bundle: .taimaLocalization)
        }
        #endif
    }

    /// Flower shares one THC scale. Hash and rosin are far stronger and
    /// edibles are dosed in milligrams, so averages and spreads keep them apart.
    public var isFlower: Bool { self == .bag || self == .jar || self == .preroll }

    /// Edibles are counted in pieces, everything else is weighed.
    public var isWeighed: Bool { self != .edible }

    public var symbol: String {
        switch self {
        case .bag: "bag.fill"
        case .preroll: "smoke.fill"
        case .jar: "cylinder.fill"
        case .hash: "cube.fill"
        case .rosin: "drop.fill"
        case .edible: "birthday.cake.fill"
        }
    }
}

/// Where a bag is in its life: unopened, being used, or used up and kept.
public enum StockState: String, Codable, CaseIterable, Sendable, Identifiable {
    case full, open, empty

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .full: String(localized: "Full", bundle: .taimaLocalization)
        case .open: String(localized: "Open", bundle: .taimaLocalization)
        case .empty: String(localized: "Empty", bundle: .taimaLocalization)
        }
    }
}

public enum ConsumptionMethod: String, Codable, CaseIterable, Sendable, Identifiable {
    case joint, vape, bong, pipe, dab, edible, other

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .joint: String(localized: "Joint", bundle: .taimaLocalization)
        case .vape: String(localized: "Vape", bundle: .taimaLocalization)
        case .bong: String(localized: "Bong", bundle: .taimaLocalization)
        case .pipe: String(localized: "Pipe", bundle: .taimaLocalization)
        case .dab: String(localized: "Dab", bundle: .taimaLocalization)
        case .edible: String(localized: "Edible", bundle: .taimaLocalization)
        case .other: String(localized: "Other", bundle: .taimaLocalization)
        }
    }

    public var symbol: String {
        switch self {
        case .joint: "smoke.fill"
        case .vape: "wind"
        case .bong: "drop.fill"
        case .pipe: "flame.fill"
        case .dab: "drop.circle.fill"
        case .edible: "birthday.cake.fill"
        case .other: "ellipsis.circle.fill"
        }
    }

    /// The ways that make sense for this kind of item: edibles are eaten,
    /// rosin is dabbed or vaped, flower isn't dabbed.
    public static func suiting(_ form: ProductForm) -> [ConsumptionMethod] {
        switch form {
        case .edible: [.edible, .other]
        case .rosin: [.dab, .vape, .joint, .bong, .other]
        case .hash: [.joint, .bong, .pipe, .vape, .other]
        case .preroll: [.joint, .other]
        case .bag, .jar: [.joint, .vape, .bong, .pipe, .edible, .other]
        }
    }
}

/// A note written at a moment, for example how a session is going.
public struct TimedNote: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var date: Date
    public var text: String
    public var photoName: String?

    public init(id: UUID = UUID(), date: Date = .now, text: String, photoName: String? = nil) {
        self.id = id
        self.date = date
        self.text = text
        self.photoName = photoName
    }
}

/// One recorded use, taken from a bag's remaining amount. Quick logs only
/// carry the amount; a full session adds how and how it felt.
public struct UsageEntry: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var date: Date
    public var grams: Double
    public var method: ConsumptionMethod?
    /// 1 (low) to 5 (great), before and after.
    public var moodBefore: Int?
    public var moodAfter: Int?
    public var note: String?
    /// Mixed with tobacco, which Trimbos singles out as an avoidable risk.
    public var withTobacco: Bool?

    public init(id: UUID = UUID(), date: Date = .now, grams: Double, method: ConsumptionMethod? = nil, moodBefore: Int? = nil, moodAfter: Int? = nil, note: String? = nil, withTobacco: Bool? = nil) {
        self.withTobacco = withTobacco
        self.id = id
        self.date = date
        self.grams = grams
        self.method = method
        self.moodBefore = moodBefore
        self.moodAfter = moodAfter
        self.note = note
    }

    public var moodChange: Int? {
        guard let moodBefore, let moodAfter else { return nil }
        return moodAfter - moodBefore
    }
}

public enum StrainType: String, Codable, CaseIterable, Sendable, Identifiable {
    case indica, sativa, hybrid

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .indica: String(localized: "Indica", bundle: .taimaLocalization)
        case .sativa: String(localized: "Sativa", bundle: .taimaLocalization)
        case .hybrid: String(localized: "Hybrid", bundle: .taimaLocalization)
        }
    }
}

/// One collected bag. Every field except the identity and dates is optional:
/// the label may be unreadable and the person decides what to fill in.
public struct Bag: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var producer: String?
    public var strainType: StrainType?
    public var thc: Potency?
    public var cbd: Potency?
    public var grams: Double?
    public var harvestedOn: Date?
    public var packedOn: Date?
    /// "Houdbaar tot" or THT, when the label prints one.
    public var bestBeforeOn: Date?
    public var collectedOn: Date
    public var productID: String?
    public var sku: String?
    public var ean: String?
    public var leafletURL: String?
    public var priceEuros: Double?
    /// The coffeeshop it came from, and its town.
    public var shop: String?
    public var shopCity: String?
    /// Legacy 1–5 stars; `score` replaces it.
    public var rating: Int?
    /// Score out of 10 in half steps.
    public var score: Double?
    public var effects: [String]?
    public var sideEffects: [String]?
    public var flavors: [String]?
    /// The person's own verdict, shown in the shop scanner.
    public var wouldBuyAgain: Bool?
    public var notes: String
    public var photoName: String?
    public var recognizedText: String
    /// Optional photo of the back of the bag, usually with the grower's details.
    public var backPhotoName: String?
    public var backRecognizedText: String?
    /// Photos of the flower itself.
    public var extraPhotoNames: [String]?
    /// The photo shown in lists; the label photo when not chosen.
    public var coverPhotoName: String?
    /// Optional in storage so records from before inventory decode as empty bags.
    public var stockState: StockState?
    /// Optional in storage so older records decode as bags.
    public var productForm: ProductForm?
    /// Prerolls in the pack.
    public var unitCount: Int?
    /// For edibles: milligrams of THC in one piece.
    public var thcMilligrams: Double?
    public var remainingGrams: Double?
    public var usageLog: [UsageEntry]?
    /// Notes written while using the bag, each with an optional photo.
    public var timedNotes: [TimedNote]?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String = "",
        producer: String? = nil,
        strainType: StrainType? = nil,
        thc: Potency? = nil,
        cbd: Potency? = nil,
        grams: Double? = nil,
        harvestedOn: Date? = nil,
        packedOn: Date? = nil,
        collectedOn: Date = .now,
        productID: String? = nil,
        sku: String? = nil,
        ean: String? = nil,
        leafletURL: String? = nil,
        priceEuros: Double? = nil,
        rating: Int? = nil,
        notes: String = "",
        photoName: String? = nil,
        recognizedText: String = "",
        backPhotoName: String? = nil,
        backRecognizedText: String? = nil,
        stock: StockState = .empty,
        form: ProductForm = .bag,
        unitCount: Int? = nil,
        remainingGrams: Double? = nil,
        usage: [UsageEntry] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.producer = producer
        self.strainType = strainType
        self.thc = thc
        self.cbd = cbd
        self.grams = grams
        self.harvestedOn = harvestedOn
        self.packedOn = packedOn
        self.collectedOn = collectedOn
        self.productID = productID
        self.sku = sku
        self.ean = ean
        self.leafletURL = leafletURL
        self.priceEuros = priceEuros
        self.rating = rating
        self.notes = notes
        self.photoName = photoName
        self.recognizedText = recognizedText
        self.backPhotoName = backPhotoName
        self.backRecognizedText = backRecognizedText
        self.stockState = stock
        self.productForm = form
        self.unitCount = unitCount
        self.remainingGrams = remainingGrams
        self.usageLog = usage
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var displayName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Self.unnamed(productForm ?? .bag) : name
    }

    static func unnamed(_ form: ProductForm) -> String {
        switch form {
        case .bag: String(localized: "Unnamed bag", bundle: .taimaLocalization)
        case .preroll: String(localized: "Unnamed preroll pack", bundle: .taimaLocalization)
        case .jar: String(localized: "Unnamed jar", bundle: .taimaLocalization)
        case .hash: String(localized: "Unnamed hash", bundle: .taimaLocalization)
        case .rosin: String(localized: "Unnamed rosin", bundle: .taimaLocalization)
        case .edible: String(localized: "Unnamed edibles", bundle: .taimaLocalization)
        }
    }

    /// Days between harvest and packing, when both dates are known and ordered.
    public var cureDays: Int? {
        guard let harvestedOn, let packedOn, packedOn >= harvestedOn else { return nil }
        return Calendar.taima.dateComponents([.day], from: harvestedOn, to: packedOn).day
    }

    /// Groups bags of the same strain: case, spacing and punctuation ignored.
    public var strainKey: String {
        StrainGroup.key(for: name)
    }

    /// Every stored photo: front, back, then flower photos.
    public var photoNames: [String] {
        [photoName, backPhotoName].compactMap { $0 } + (extraPhotoNames ?? [])
    }

    /// Every photo file the bag owns, including those on notes: what backups
    /// carry and what deleting the bag removes.
    public var storedPhotoNames: [String] {
        photoNames + (timedNotes ?? []).compactMap(\.photoName)
    }

    public var noteLog: [TimedNote] {
        get { timedNotes ?? [] }
        set { timedNotes = newValue.isEmpty ? nil : newValue }
    }

    /// The photo that represents the bag: the chosen one, else the front.
    public var mainPhoto: String? {
        if let coverPhotoName, photoNames.contains(coverPhotoName) { return coverPhotoName }
        return photoName ?? photoNames.first
    }

    /// All photos with the main one first, for galleries.
    public var galleryPhotos: [String] {
        guard let main = mainPhoto else { return photoNames }
        return [main] + photoNames.filter { $0 != main }
    }

    public var pricePerGram: Double? {
        guard let priceEuros, let grams, grams > 0 else { return nil }
        return priceEuros / grams
    }
}

public extension Calendar {
    /// Label dates are calendar days. A fixed Gregorian calendar keeps them
    /// stable regardless of the device's calendar setting.
    static let taima: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        // Follows time zone changes, so "today" and weeks are right after travel.
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }()
}

// MARK: - Lenient decoding

/// Values written by a newer Taima decode as a sensible default instead of
/// making the whole bag unreadable, so an older build never hides bags.
protocol LenientEnum: RawRepresentable, Decodable where RawValue == String {
    static var fallback: Self { get }
}

extension LenientEnum {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? Self.fallback
    }
}

extension ProductForm: LenientEnum { static var fallback: ProductForm { .bag } }
extension StockState: LenientEnum { static var fallback: StockState { .empty } }
extension StrainType: LenientEnum { static var fallback: StrainType { .hybrid } }
extension ConsumptionMethod: LenientEnum { static var fallback: ConsumptionMethod { .other } }
