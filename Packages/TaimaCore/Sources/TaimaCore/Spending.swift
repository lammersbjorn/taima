import Foundation

/// Money and shops, from the prices and shops the person entered.
public struct SpendingSummary: Sendable {
    public struct Month: Hashable, Sendable, Identifiable {
        public var start: Date
        public var euros: Double
        public var id: Date { start }
    }

    public struct Shop: Hashable, Sendable, Identifiable {
        public var name: String
        public var city: String?
        public var visits: Int
        public var euros: Double
        public var pricePerGram: Double?
        public var id: String { name.lowercased() }
    }

    public var total: Double
    public var pricedBags: Int
    public var months: [Month]
    public var shops: [Shop]
    public var findings: [String]

    public init(bags: [Bag], calendar: Calendar = .taima) {
        let priced = bags.filter { $0.priceEuros != nil }
        pricedBags = priced.count
        total = priced.compactMap(\.priceEuros).reduce(0, +)

        var monthTotals: [Date: Double] = [:]
        for bag in priced {
            guard let start = calendar.dateInterval(of: .month, for: bag.collectedOn)?.start else { continue }
            monthTotals[start, default: 0] += bag.priceEuros ?? 0
        }
        months = monthTotals.map { Month(start: $0.key, euros: $0.value) }.sorted { $0.start < $1.start }

        var groups: [String: [Bag]] = [:]
        for bag in bags {
            guard let name = bag.shop?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { continue }
            groups[name.lowercased(), default: []].append(bag)
        }
        shops = groups.values.map { group in
            // Flower only: hash per gram would make a shop look expensive.
            let perGram = group.filter(\.form.isFlower).compactMap(\.pricePerGram)
            return Shop(
                name: group[0].shop ?? "",
                city: group.compactMap(\.shopCity).first { !$0.isEmpty },
                visits: group.count,
                euros: group.compactMap(\.priceEuros).reduce(0, +),
                pricePerGram: perGram.isEmpty ? nil : perGram.reduce(0, +) / Double(perGram.count)
            )
        }
        .sorted { ($0.visits, $0.euros) > ($1.visits, $1.euros) }

        var findings: [String] = []
        let compared = shops.filter { $0.pricePerGram != nil }
        if compared.count >= 2, let cheapest = compared.min(by: { $0.pricePerGram! < $1.pricePerGram! }) {
            findings.append("\(cheapest.name) has been cheapest for you, \(Self.euros(cheapest.pricePerGram!)) per gram of flower on average.")
        }
        if let favourite = shops.first, favourite.visits >= 3 {
            findings.append("Most of your bags come from \(favourite.name) (\(favourite.visits)).")
        }
        self.findings = findings
    }

    static func euros(_ value: Double) -> String {
        value.formatted(.currency(code: "EUR"))
    }
}
