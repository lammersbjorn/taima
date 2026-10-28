import Foundation

/// Answers "do I have this?" for codes and text seen by the live scanner.
public enum CollectionLookup {
    public enum Result: Equatable, Sendable {
        /// This exact package: the product ID matches.
        case sameBag(Bag)
        /// The same product line (EAN) or strain name, a different package.
        case sameProduct([Bag])
        case sameStrain(name: String, bags: [Bag])
        case new
    }

    public static func find(payloads: [String], texts: [String], in bags: [Bag], catalog: StrainCatalog? = nil) -> Result {
        let codes = Set(payloads.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        if let bag = bags.first(where: { $0.productID.map { codes.contains($0.lowercased()) } ?? false }) {
            return .sameBag(bag)
        }
        let byEAN = bags.filter { $0.ean.map(codes.contains) ?? false }
        if !byEAN.isEmpty { return .sameProduct(byEAN) }
        let bySKU = bags.filter { $0.sku.map { codes.contains($0.lowercased()) } ?? false }
        if !bySKU.isEmpty { return .sameProduct(bySKU) }

        // Text: a line that names one of your strains, directly or through the library.
        for text in texts where text.count >= 3 {
            let key = StrainGroup.key(for: text)
            let direct = text.count < 4 ? [] : bags.filter { !$0.strainKey.isEmpty && ($0.strainKey == key || key.contains($0.strainKey) && $0.strainKey.count >= 5) }
            if !direct.isEmpty { return .sameStrain(name: direct[0].displayName, bags: direct) }
            if let catalog, let match = catalog.match(productName: text), match.match != .partial {
                let owned = bags.filter { catalog.match(productName: $0.name)?.info.id == match.info.id }
                if !owned.isEmpty { return .sameStrain(name: match.info.name, bags: owned) }
            }
        }
        return .new
    }
}
