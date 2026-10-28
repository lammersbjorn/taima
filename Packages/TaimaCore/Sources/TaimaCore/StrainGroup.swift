import Foundation

/// A strain the person wants to try.
public struct WishItem: Codable, Hashable, Sendable, Identifiable {
    public var key: String
    public var name: String
    public var addedAt: Date
    public var id: String { key }

    public init(key: String, name: String, addedAt: Date = .now) {
        self.key = key
        self.name = name
        self.addedAt = addedAt
    }
}

/// Every bag of one strain, for the combined view.
public struct StrainGroup: Identifiable, Hashable, Sendable {
    public var key: String
    public var name: String
    public var bags: [Bag]

    public var id: String { key }
    public var totalGrams: Double { bags.filter(\.form.isWeighed).compactMap(\.grams).reduce(0, +) }
    public var producers: [String] {
        var seen = Set<String>()
        return bags.compactMap(\.producer).filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }

    public var thcValues: [Double] { bags.compactMap { $0.thc?.percent } }
    public var averageTHC: Double? {
        thcValues.isEmpty ? nil : thcValues.reduce(0, +) / Double(thcValues.count)
    }
    public var thcRange: ClosedRange<Double>? {
        guard let low = thcValues.min(), let high = thcValues.max() else { return nil }
        return low...high
    }
    public var averageRating: Double? {
        let ratings = bags.compactMap(\.rating10)
        return ratings.isEmpty ? nil : ratings.reduce(0, +) / Double(ratings.count)
    }
    public var lastCollected: Date { bags.map(\.collectedOn).max() ?? .distantPast }
    public var photoName: String? { bags.sorted { $0.collectedOn > $1.collectedOn }.compactMap(\.mainPhoto).first }

    public static func key(for name: String) -> String {
        let spaced = String(name.lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
            .map { $0.isLetter || $0.isNumber ? $0 : " " })
        return spaced.split(separator: " ").joined(separator: " ")
    }

    /// Groups bags by strain, the most collected first.
    public static func group(_ bags: [Bag]) -> [StrainGroup] {
        let grouped = Dictionary(grouping: bags) { $0.strainKey }
        return grouped.map { key, bags in
            let sorted = bags.sorted { $0.collectedOn > $1.collectedOn }
            return StrainGroup(key: key, name: sorted.first?.displayName ?? "Unnamed", bags: sorted)
        }
        .sorted { ($0.bags.count, $0.lastCollected) > ($1.bags.count, $1.lastCollected) }
    }
}
