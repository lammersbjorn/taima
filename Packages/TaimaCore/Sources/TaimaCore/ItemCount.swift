import Foundation

/// Counts that name what was collected: "3 bags" when everything is a bag,
/// "10 items" for a mix of bags, prerolls, jars and hash.
public enum ItemCount {
    public static func label(_ bags: [Bag]) -> String {
        label(count: bags.count, forms: Set(bags.map(\.form)))
    }

    public static func label(count: Int, forms: Set<ProductForm>) -> String {
        if forms.count == 1, let form = forms.first { return form.counted(count) }
        return String(localized: "\(count) items", bundle: .module)
    }

    /// "7 bags, 2 preroll packs and 1 jar"; nil when there is only one kind.
    public static func breakdown(_ bags: [Bag]) -> String? {
        let counts = Dictionary(grouping: bags, by: \.form).mapValues(\.count)
        guard counts.count > 1 else { return nil }
        let parts = ProductForm.allCases.compactMap { form in counts[form].map { form.counted($0) } }
        return parts.formatted(.list(type: .and))
    }
}
