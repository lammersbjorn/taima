import Foundation

/// A finished or running tolerance break.
public struct BreakRecord: Codable, Hashable, Sendable, Identifiable {
    public var start: Date
    public var end: Date?
    public var id: Date { start }

    public init(start: Date, end: Date? = nil) {
        self.start = start
        self.end = end
    }

    public func days(now: Date = .now, calendar: Calendar = .taima) -> Int {
        StashMath.breakDays(since: start, now: end ?? now, calendar: calendar)
    }

    /// What the break kept in the bag and the wallet, at the pace before it.
    public func savings(dailyGrams: Double, pricePerGram: Double?, now: Date = .now) -> (grams: Double, euros: Double?) {
        let grams = Double(days(now: now)) * dailyGrams
        return (grams, pricePerGram.map { $0 * grams })
    }
}

/// The CUDIT-R self-check (Adamson et al., 2010, Drug and Alcohol
/// Dependence 110:137–143; distributed as public domain with citation).
/// A screen, not a diagnosis: Taima shows the score and neutral wording.
public enum SelfCheck {
    public struct Question: Sendable {
        public var text: String
        public var answers: [(label: String, points: Int)]
    }

    static let frequency = [("Never", 0), ("Less than monthly", 1), ("Monthly", 2), ("Weekly", 3), ("Daily or almost daily", 4)]

    public static let questions: [Question] = [
        Question(text: "How often do you use cannabis?", answers: [("Never", 0), ("Monthly or less", 1), ("2–4 times a month", 2), ("2–3 times a week", 3), ("4 or more times a week", 4)]),
        Question(text: "How many hours were you \"stoned\" on a typical day when you had been using cannabis?", answers: [("Less than 1", 0), ("1 or 2", 1), ("3 or 4", 2), ("5 or 6", 3), ("7 or more", 4)]),
        Question(text: "How often during the past 6 months did you find that you were not able to stop using cannabis once you had started?", answers: frequency),
        Question(text: "How often during the past 6 months did you fail to do what was normally expected from you because of using cannabis?", answers: frequency),
        Question(text: "How often in the past 6 months have you devoted a great deal of your time to getting, using, or recovering from cannabis?", answers: frequency),
        Question(text: "How often in the past 6 months have you had a problem with your memory or concentration after using cannabis?", answers: frequency),
        Question(text: "How often do you use cannabis in situations that could be physically hazardous, such as driving, operating machinery, or caring for children?", answers: frequency),
        Question(text: "Have you ever thought about cutting down, or stopping, your use of cannabis?", answers: [("Never", 0), ("Yes, but not in the past 6 months", 2), ("Yes, during the past 6 months", 4)])
    ]

    public static func score(_ answers: [Int]) -> Int {
        zip(questions, answers).map { question, index in question.answers.indices.contains(index) ? question.answers[index].points : 0 }.reduce(0, +)
    }

    /// Neutral wording for a score, following the published bands.
    public static func summary(for score: Int) -> String {
        switch score {
        case ..<8: "Your answers fall in the lower range."
        case 8..<12: "Your answers fall in a range where many people choose to look at their use more closely."
        default: "Your answers fall in a range where talking it through with someone can help. That is not a diagnosis."
        }
    }

    public struct Result: Codable, Hashable, Sendable, Identifiable {
        public var date: Date
        public var score: Int
        public var id: Date { date }
        public init(date: Date = .now, score: Int) {
            self.date = date
            self.score = score
        }
    }
}

/// A look back at one year, for a share card.
public struct YearReview: Sendable {
    public var year: Int
    public var bagCount: Int
    public var grams: Double
    public var strainCount: Int
    public var growerCount: Int
    public var favourite: Bag?
    public var topGrower: String?
    public var topEffect: String?
    public var busiestMonth: Date?

    public init(bags: [Bag], year: Int, calendar: Calendar = .taima) {
        self.year = year
        let inYear = bags.filter { calendar.component(.year, from: $0.collectedOn) == year }
        bagCount = inYear.count
        grams = inYear.compactMap(\.grams).reduce(0, +)
        strainCount = Set(inYear.map(\.strainKey)).count
        growerCount = Set(inYear.compactMap(\.producer)).count
        favourite = inYear.filter { $0.rating10 != nil }.max { ($0.rating10 ?? 0, $1.collectedOn) < ($1.rating10 ?? 0, $0.collectedOn) }
        topGrower = CollectionStats(bags: inYear, calendar: calendar).producers.first { $0.label != "Unknown" }?.label
        topEffect = ExperienceInsights(bags: inYear).positive.first?.name
        busiestMonth = CollectionStats(bags: inYear, calendar: calendar).months.max { $0.count < $1.count }?.start
    }
}

public extension Array where Element == Bag {
    /// Full and open bags, oldest pack date first: what to use before it dries out.
    var useFirstOrder: [Bag] {
        sorted { ($0.packedOn ?? .distantFuture, $0.collectedOn) < ($1.packedOn ?? .distantFuture, $1.collectedOn) }
    }
}
