import Foundation

/// Figures for the statistics tab, computed from saved bags only.
public struct CollectionStats: Sendable {
    public struct Count: Hashable, Sendable, Identifiable {
        public var label: String
        public var count: Int
        public var grams: Double
        public var id: String { label }
    }

    public struct Month: Hashable, Sendable, Identifiable {
        public var start: Date
        public var count: Int
        public var grams: Double
        public var id: Date { start }
    }

    public struct THCBin: Hashable, Sendable, Identifiable {
        public var lowerBound: Int
        public var count: Int
        public var id: Int { lowerBound }
        public var label: String { "\(lowerBound)–\(lowerBound + 1)%" }
    }

    public var bagCount: Int
    public var totalGrams: Double
    public var averageTHC: Double?
    public var highestTHC: Bag?
    public var strainCount: Int
    public var producerCount: Int
    public var averageCureDays: Double?
    public var averageAgeAtCollectionDays: Double?
    public var totalSpent: Double?
    public var averagePricePerGram: Double?
    public var averageRating: Double?
    public var months: [Month]
    public var thcBins: [THCBin]
    public var producers: [Count]
    public var sizes: [Count]
    public var strainTypes: [Count]
    public var cureTimes: [(bag: Bag, days: Int)]

    public init(bags: [Bag], calendar: Calendar = .taima) {
        bagCount = bags.count
        totalGrams = bags.compactMap(\.grams).reduce(0, +)

        let thcValues = bags.compactMap { $0.thc?.percent }
        averageTHC = thcValues.isEmpty ? nil : thcValues.reduce(0, +) / Double(thcValues.count)
        highestTHC = bags.filter { $0.thc != nil }.max { $0.thc!.percent < $1.thc!.percent }

        strainCount = Set(bags.map { $0.displayName.lowercased() }).count
        let producerNames = bags.compactMap { $0.producer?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        producerCount = Set(producerNames.map { $0.lowercased() }).count

        cureTimes = bags.compactMap { bag in bag.cureDays.map { (bag, $0) } }
        averageCureDays = cureTimes.isEmpty ? nil : Double(cureTimes.map(\.days).reduce(0, +)) / Double(cureTimes.count)

        let ages = bags.compactMap { bag -> Int? in
            guard let packed = bag.packedOn, bag.collectedOn >= packed else { return nil }
            return calendar.dateComponents([.day], from: packed, to: bag.collectedOn).day
        }
        averageAgeAtCollectionDays = ages.isEmpty ? nil : Double(ages.reduce(0, +)) / Double(ages.count)

        let prices = bags.compactMap(\.priceEuros)
        totalSpent = prices.isEmpty ? nil : prices.reduce(0, +)
        let perGram = bags.compactMap(\.pricePerGram)
        averagePricePerGram = perGram.isEmpty ? nil : perGram.reduce(0, +) / Double(perGram.count)
        let ratings = bags.compactMap(\.rating10)
        averageRating = ratings.isEmpty ? nil : ratings.reduce(0, +) / Double(ratings.count)

        var monthTotals: [Date: Month] = [:]
        for bag in bags {
            guard let start = calendar.dateInterval(of: .month, for: bag.collectedOn)?.start else { continue }
            var month = monthTotals[start] ?? Month(start: start, count: 0, grams: 0)
            month.count += 1
            month.grams += bag.grams ?? 0
            monthTotals[start] = month
        }
        months = monthTotals.values.sorted { $0.start < $1.start }

        var bins: [Int: Int] = [:]
        for value in thcValues { bins[Int(value.rounded(.down)), default: 0] += 1 }
        if let low = bins.keys.min(), let high = bins.keys.max() {
            thcBins = (low...high).map { THCBin(lowerBound: $0, count: bins[$0] ?? 0) }
        } else {
            thcBins = []
        }

        func counts(_ key: (Bag) -> String?) -> [Count] {
            var totals: [String: Count] = [:]
            for bag in bags {
                guard let label = key(bag) else { continue }
                var count = totals[label] ?? Count(label: label, count: 0, grams: 0)
                count.count += 1
                count.grams += bag.grams ?? 0
                totals[label] = count
            }
            return totals.values.sorted { ($0.count, $1.label) > ($1.count, $0.label) }
        }
        producers = counts { bag in
            let name = bag.producer?.trimmingCharacters(in: .whitespaces) ?? ""
            return name.isEmpty ? "Unknown" : name
        }
        sizes = counts { bag in
            bag.grams.map { $0.formatted(.number.precision(.fractionLength(0...1))) + " g" }
        }
        strainTypes = counts { $0.strainType?.label }
    }
}
