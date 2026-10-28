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
        public var label: String { String(localized: "\(lowerBound)–\(lowerBound + 1)%", bundle: .module) }
    }

    public var bagCount: Int
    /// What kinds were collected, for wording counts.
    public var forms: Set<ProductForm>
    public var totalGrams: Double
    /// Flower only (bags, prerolls, jars): hash would skew it.
    public var averageTHC: Double?
    public var highestTHC: Bag?
    /// Hash on its own scale.
    public var averageHashTHC: Double?
    public var hashCount: Int
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
        forms = Set(bags.map(\.form))
        totalGrams = bags.compactMap(\.grams).reduce(0, +)

        let flower = bags.filter(\.form.isFlower)
        let hash = bags.filter { !$0.form.isFlower }
        hashCount = hash.count
        let thcValues = flower.compactMap { $0.thc?.percent }
        averageTHC = thcValues.isEmpty ? nil : thcValues.reduce(0, +) / Double(thcValues.count)
        highestTHC = flower.filter { $0.thc != nil }.max { $0.thc!.percent < $1.thc!.percent }
        let hashTHC = hash.compactMap { $0.thc?.percent }
        averageHashTHC = hashTHC.isEmpty ? nil : hashTHC.reduce(0, +) / Double(hashTHC.count)

        // Grouped the way Collection's strain view groups them.
        strainCount = Set(bags.map(\.strainKey).filter { !$0.isEmpty }).count
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
        // Hash costs far more per gram; the average is for flower.
        let perGram = flower.compactMap(\.pricePerGram)
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
            return name.isEmpty ? String(localized: "Unknown", bundle: .module) : name
        }
        // "5 g" for bags; other kinds say what they are, so a 1 g preroll
        // pack isn't counted with 1 g bags.
        sizes = counts { bag in
            bag.grams.map { grams in
                let weight = grams.formatted(.number.precision(.fractionLength(0...2))) + " g"
                switch bag.form {
                case .bag: return weight
                case .preroll:
                    if let units = bag.unitCount, units > 1, let per = bag.gramsPerUnit {
                        let each = per.formatted(.number.precision(.fractionLength(0...2)))
                        return String(localized: "\(units) × \(each) g prerolls", bundle: .module)
                    }
                    return String(localized: "\(weight) prerolls", bundle: .module)
                case .jar: return String(localized: "\(weight) jar", bundle: .module)
                case .hash: return String(localized: "\(weight) hash", bundle: .module)
                }
            }
        }
        strainTypes = counts { $0.strainType?.label }
    }
}
