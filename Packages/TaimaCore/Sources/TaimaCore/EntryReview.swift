import Foundation

/// After an update reads labels better, older bags can be re-read. Only
/// fields that are still empty are offered, and the person accepts each
/// bag's changes; nothing they entered is overwritten.
public enum EntryReview {
    /// Bumped whenever label reading improves enough to be worth a re-read.
    public static let readerVersion = 2

    public struct Change: Hashable, Sendable, Identifiable {
        public var field: String
        public var old: String?
        public var new: String
        public var id: String { field }
    }

    public struct Suggestion: Identifiable, Sendable {
        public var original: Bag
        public var updated: Bag
        public var changes: [Change]
        public var id: UUID { original.id }
    }

    /// What a fresh reading (and a library type) would add to a bag.
    public static func suggest(for bag: Bag, reading: LabelReading, libraryType: StrainType? = nil, grower: String? = nil) -> Suggestion? {
        var updated = bag
        updated.fillEmpty(from: reading)
        if updated.strainType == nil, let libraryType { updated.strainType = libraryType }
        if (updated.producer ?? "").isEmpty, let grower { updated.producer = grower }
        let cleaned = LabelParser.cleanName(updated.name)
        if !cleaned.isEmpty, cleaned != updated.name, cleaned.count >= updated.name.count - 3 { updated.name = cleaned }
        let changes = describe(from: bag, to: updated)
        return changes.isEmpty ? nil : Suggestion(original: bag, updated: updated, changes: changes)
    }

    static func describe(from old: Bag, to new: Bag) -> [Change] {
        func day(_ date: Date?) -> String? { date?.formatted(date: .abbreviated, time: .omitted) }
        var changes: [Change] = []
        func compare(_ field: String, _ a: String?, _ b: String?) {
            guard let b, !b.isEmpty, a != b else { return }
            changes.append(Change(field: field, old: (a?.isEmpty ?? true) ? nil : a, new: b))
        }
        compare(String(localized: "Name", bundle: .module), old.name, new.name)
        compare(String(localized: "Grower", bundle: .module), old.producer, new.producer)
        compare(String(localized: "Type", bundle: .module), old.strainType?.label, new.strainType?.label)
        compare("THC", old.thc?.label, new.thc?.label)
        compare("CBD", old.cbd?.label, new.cbd?.label)
        compare(String(localized: "Weight", bundle: .module), old.grams.map { "\($0.formatted()) g" }, new.grams.map { "\($0.formatted()) g" })
        compare(String(localized: "Harvested", bundle: .module), day(old.harvestedOn), day(new.harvestedOn))
        compare(String(localized: "Packed", bundle: .module), day(old.packedOn), day(new.packedOn))
        compare(String(localized: "Best before", bundle: .module), day(old.bestBeforeOn), day(new.bestBeforeOn))
        compare(String(localized: "Product code", bundle: .module), old.productID, new.productID)
        compare("SKU", old.sku, new.sku)
        compare("EAN", old.ean, new.ean)
        compare(String(localized: "Product", bundle: .module), old.productForm.map(\.label), new.productForm.flatMap { $0 == .bag && old.productForm == nil ? nil : $0.label })
        compare(String(localized: "Prerolls", bundle: .module), old.unitCount.map(String.init), new.unitCount.map(String.init))
        return changes
    }
}

public extension Bag {
    /// Takes values from a reading only where the bag has none.
    mutating func fillEmpty(from reading: LabelReading) {
        if name.trimmingCharacters(in: .whitespaces).isEmpty, let value = reading.name { name = value }
        if (producer ?? "").isEmpty, let value = reading.producer { producer = value }
        if strainType == nil { strainType = reading.strainType }
        if thc == nil { thc = reading.thc }
        if cbd == nil { cbd = reading.cbd }
        if grams == nil { grams = reading.grams }
        if harvestedOn == nil { harvestedOn = reading.harvestedOn }
        if packedOn == nil { packedOn = reading.packedOn }
        if bestBeforeOn == nil { bestBeforeOn = reading.bestBeforeOn }
        if productID == nil { productID = reading.productID }
        if sku == nil { sku = reading.sku }
        if ean == nil { ean = reading.ean }
        if leafletURL == nil { leafletURL = reading.leafletURL }
        if form == .bag, let value = reading.form, value != .bag { form = value }
        if unitCount == nil { unitCount = reading.unitCount }
    }
}
