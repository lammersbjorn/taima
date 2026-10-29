import Foundation

/// Patterns in logged uses. Plain descriptions of the person's own log.
public struct SessionInsights: Sendable {
    public struct Slice: Hashable, Sendable, Identifiable {
        public var label: String
        public var count: Int
        public var grams: Double
        public var id: String { label }
    }

    public struct Lift: Hashable, Sendable, Identifiable {
        public var label: String
        public var change: Double
        public var count: Int
        public var id: String { label }
    }

    public var sessionCount: Int
    /// Sessions per hour of day, 0–23.
    public var byHour: [Int]
    /// Sessions per weekday, Monday first.
    public var byWeekday: [Int]
    public var methods: [Slice]
    public var liftByStrain: [Lift]
    public var liftByMethod: [Lift]
    public var liftByTHC: [Lift]
    public var liftByTimeOfDay: [Lift]
    /// Share of sessions noted as mixed with tobacco, of those where it was noted.
    public var tobaccoShare: Double?
    public var findings: [String]

    public init(bags: [Bag], calendar: Calendar = .taima) {
        let sessions = bags.flatMap { bag in bag.usage.map { (bag, $0) } }
        sessionCount = sessions.count
        var hours = Array(repeating: 0, count: 24)
        var weekdays = Array(repeating: 0, count: 7)
        for (_, entry) in sessions {
            hours[calendar.component(.hour, from: entry.date)] += 1
            // Calendar weekday is 1 = Sunday; shift so Monday is first.
            weekdays[(calendar.component(.weekday, from: entry.date) + 5) % 7] += 1
        }
        byHour = hours
        byWeekday = weekdays

        var methodTotals: [ConsumptionMethod: Slice] = [:]
        for (bag, entry) in sessions {
            guard let method = entry.method else { continue }
            var slice = methodTotals[method] ?? Slice(label: method.label, count: 0, grams: 0)
            slice.count += 1
            if bag.form.isWeighed { slice.grams += entry.grams }
            methodTotals[method] = slice
        }
        methods = methodTotals.values.sorted { ($0.count, $0.grams, $1.label) > ($1.count, $1.grams, $0.label) }

        func lifts(_ key: (Bag, UsageEntry) -> String?) -> [Lift] {
            var groups: [String: [Int]] = [:]
            for (bag, entry) in sessions {
                guard let change = entry.moodChange, let label = key(bag, entry) else { continue }
                groups[label, default: []].append(change)
            }
            return groups.map { Lift(label: $0.key, change: Double($0.value.reduce(0, +)) / Double($0.value.count), count: $0.value.count) }
                .sorted { ($0.change, $0.count) > ($1.change, $1.count) }
        }
        liftByStrain = lifts { bag, _ in bag.displayName }
        liftByMethod = lifts { _, entry in entry.method?.label }
        liftByTHC = lifts { bag, _ in
            guard let thc = bag.thc?.percent else { return nil }
            // Hash and rosin are far stronger; a bucket of their own keeps flower comparable.
            if !bag.form.isFlower { return bag.form.label }
            return thc < 18 ? String(localized: "Under 18% THC", bundle: .taimaLocalization) : thc < 24 ? "18–24% THC" : String(localized: "24% THC or more", bundle: .taimaLocalization)
        }
        liftByTimeOfDay = lifts { _, entry in
            switch calendar.component(.hour, from: entry.date) {
            case 5..<12: String(localized: "Morning", bundle: .taimaLocalization)
            case 12..<17: String(localized: "Afternoon", bundle: .taimaLocalization)
            case 17..<22: String(localized: "Evening", bundle: .taimaLocalization)
            default: String(localized: "Night", bundle: .taimaLocalization)
            }
        }
        let tobaccoNoted = sessions.compactMap { $0.1.withTobacco }
        tobaccoShare = tobaccoNoted.count >= 3 ? Double(tobaccoNoted.filter { $0 }.count) / Double(tobaccoNoted.count) : nil

        var findings: [String] = []
        if sessionCount >= 5 {
            let evening = hours[18...23].reduce(0, +) + hours[0...2].reduce(0, +)
            let share = Double(evening) / Double(sessionCount)
            if share >= 0.6 {
                findings.append(String(localized: "Most of your sessions are in the evening (\(Int((share * 100).rounded()))%).", bundle: .taimaLocalization))
            } else if let peak = hours.indices.max(by: { hours[$0] < hours[$1] }) {
                findings.append(String(localized: "You log most often around \(peak):00.", bundle: .taimaLocalization))
            }
        }
        if let best = liftByStrain.first(where: { $0.count >= 2 }), best.change > 0 {
            findings.append(String(localized: "\(best.label) lifted your mood most, \(Self.signed(best.change)) on average over \(best.count) sessions.", bundle: .taimaLocalization))
        }
        let methodAverages = methods.filter { $0.count >= 2 }
        if methodAverages.count >= 2,
           let heavy = methodAverages.max(by: { $0.grams / Double($0.count) < $1.grams / Double($1.count) }),
           let light = methodAverages.min(by: { $0.grams / Double($0.count) < $1.grams / Double($1.count) }), heavy != light {
            findings.append(String(localized: "A \(heavy.label.lowercased()) session uses \(Self.grams(heavy.grams / Double(heavy.count))) on average, a \(light.label.lowercased()) session \(Self.grams(light.grams / Double(light.count))).", bundle: .taimaLocalization))
        }
        if let share = tobaccoShare, share > 0 {
            findings.append(String(localized: "\(Int((share * 100).rounded()))% of the sessions where you noted it were mixed with tobacco.", bundle: .taimaLocalization))
        }
        if let best = liftByTimeOfDay.first(where: { $0.count >= 3 }), let worst = liftByTimeOfDay.last(where: { $0.count >= 3 }),
           best != worst, best.change - worst.change >= 1 {
            findings.append(String(localized: "Your mood lifted more in the \(best.label.lowercased()) than at \(worst.label == String(localized: "Night", bundle: .taimaLocalization) ? String(localized: "night", bundle: .taimaLocalization) : String(localized: "the \(worst.label.lowercased())", bundle: .taimaLocalization)).", bundle: .taimaLocalization))
        }
        self.findings = findings
    }

    static func signed(_ value: Double) -> String {
        (value >= 0 ? "+" : "") + value.formatted(.number.precision(.fractionLength(0...1)))
    }

    static func grams(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2))) + " g"
    }
}
