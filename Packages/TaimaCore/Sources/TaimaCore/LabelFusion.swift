import Foundation

/// Combines readings of many video frames of one label. Every field is
/// decided by vote, so one misread frame cannot beat several clear ones.
public struct LabelFusion: Sendable {
    public static let keyFields: [LabelField] = [.name, .thc, .grams, .packedOn, .productID]

    public private(set) var frames = 0
    private var votes: [LabelField: [LabelReading.Value: Int]] = [:]
    private var order: [LabelField: [LabelReading.Value]] = [:]
    private var evidence: [LabelField: [LabelReading.Value: FieldConfidence]] = [:]
    private var keys: [String] = []
    private var lines: [String] = []

    public init() {}

    public mutating func add(_ reading: LabelReading) {
        frames += 1
        for field in reading.detectedFields {
            guard let value = reading.value(for: field) else { continue }
            votes[field, default: [:]][value, default: 0] += 1
            if !(order[field] ?? []).contains(value) { order[field, default: []].append(value) }
            if let incoming = reading.confidence[field], incoming.score > (evidence[field]?[value]?.score ?? -1) {
                evidence[field, default: [:]][value] = incoming
            }
        }
        for key in reading.producerKeys where !keys.contains(key) { keys.append(key) }
        for line in reading.text.split(separator: "\n").map(String.init) where !lines.contains(line) { lines.append(line) }
    }

    /// Ties go to the earliest value; names prefer the fuller text.
    public var reading: LabelReading {
        var reading = LabelReading()
        for field in LabelField.allCases {
            guard let table = votes[field], let maximum = table.values.max() else { continue }
            let tied = (order[field] ?? []).filter { table[$0] == maximum }
            var winner = tied.first
            if field == .name || field == .producer {
                for value in tied {
                    if case .text(let text) = value, case .text(let current) = winner, text.count > current.count { winner = value }
                }
            }
            guard let winner else { continue }
            reading.set(winner, for: field)
            if var confidence = evidence[field]?[winner] {
                confidence.agreement = Double(table[winner] ?? 0) / Double(table.values.reduce(0, +))
                confidence.isAmbiguous = confidence.isAmbiguous || tied.count > 1
                reading.confidence[field] = confidence
            }
        }
        reading.producerKeys = keys
        reading.text = lines.joined(separator: "\n")
        return reading
    }

    public var found: Set<LabelField> { reading.detectedFields }

    /// Share of the key fields found, 0...1.
    public var coverage: Double {
        Double(Self.keyFields.filter(found.contains).count) / Double(Self.keyFields.count)
    }

    public var isComplete: Bool { coverage >= 1 }
}
