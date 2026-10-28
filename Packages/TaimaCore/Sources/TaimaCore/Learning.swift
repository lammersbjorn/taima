import Foundation

/// Corrections the person made to names Taima read, kept on the phone and
/// applied to later scans: "Miix" became "Mix" once, so it does again.
public struct CorrectionMemory: Codable, Sendable, Equatable {
    /// Misread word (lowercased) to the word the person wrote.
    public private(set) var words: [String: String] = [:]

    public init() {}

    /// Learns word-level fixes when the saved name has the same words as
    /// the reading, with small spelling changes. Bigger rewrites are a
    /// different name, not a misreading, and teach nothing.
    public mutating func learn(read: String?, saved: String) {
        guard let read else { return }
        let readWords = read.split(separator: " ").map(String.init)
        let savedWords = saved.split(separator: " ").map(String.init)
        guard readWords.count == savedWords.count, readWords != savedWords else { return }
        for (wrong, right) in zip(readWords, savedWords) where wrong != right {
            let distance = Self.editDistance(wrong.lowercased(), right.lowercased())
            guard wrong.count >= 3, distance > 0, distance <= max(1, wrong.count / 3) else { continue }
            words[wrong.lowercased()] = right
        }
    }

    public func apply(to name: String) -> String {
        guard !words.isEmpty else { return name }
        return name.split(separator: " ").map { word in words[word.lowercased()] ?? String(word) }.joined(separator: " ")
    }

    public mutating func forget(_ wrong: String) { words[wrong] = nil }

    static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        guard !a.isEmpty else { return b.count }
        guard !b.isEmpty else { return a.count }
        var previous = Array(0...b.count)
        for i in 1...a.count {
            var current = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            previous = current
        }
        return previous[b.count]
    }
}

/// What a person may choose to share to improve label reading for
/// everyone: the recognised text and the corrected fields. Product codes
/// and barcodes are removed; no photo, price, shop, note or own date.
public struct LabelSample: Codable, Sendable {
    public struct Field: Codable, Sendable, Equatable {
        public var field: String
        public var read: String?
        public var corrected: String?
    }

    public var appVersion: String
    public var text: String
    public var fields: [Field]

    /// Fields where the reading and the saved bag differ.
    public static func make(reading: LabelReading, saved: Bag, appVersion: String) -> LabelSample? {
        func day(_ date: Date?) -> String? { date.map { $0.formatted(.iso8601.year().month().day()) } }
        let pairs: [(String, String?, String?)] = [
            ("name", reading.name, saved.name.isEmpty ? nil : saved.name),
            ("producer", reading.producer, saved.producer),
            ("thc", reading.thc?.label, saved.thc?.label),
            ("cbd", reading.cbd?.label, saved.cbd?.label),
            ("grams", reading.grams.map { String($0) }, saved.grams.map { String($0) }),
            ("harvested", day(reading.harvestedOn), day(saved.harvestedOn)),
            ("packed", day(reading.packedOn), day(saved.packedOn)),
            ("form", (reading.form ?? .bag).rawValue, saved.form.rawValue),
            ("prerolls", reading.unitCount.map(String.init), saved.unitCount.map(String.init))
        ]
        let fields = pairs.filter { $0.1 != $0.2 }.map { Field(field: $0.0, read: $0.1, corrected: $0.2) }
        guard !fields.isEmpty, !reading.text.isEmpty else { return nil }
        return LabelSample(appVersion: appVersion, text: redact(reading.text, codes: [reading.productID, reading.ean, reading.sku].compactMap { $0 }), fields: fields)
    }

    /// Removes package identifiers: PRD codes, including misread or wrapped
    /// ones, EANs and other long numbers, and the reading's own codes.
    public static func redact(_ text: String, codes: [String] = []) -> String {
        var result = text
        for code in codes where code.count >= 6 {
            result = result.replacingOccurrences(of: code, with: "[code removed]", options: .caseInsensitive)
        }
        // A PRD prefix, however it was read, takes the rest of its line with it.
        result = result.replacingOccurrences(
            of: #"(?i)\bP\s?R\s?[D0O][\s:-][^\n]*"#, with: "PRD-[removed]", options: .regularExpression)
        result = replacing(#"[0-9A-Za-z]{2,}(?:-[0-9A-Za-z]{2,})+|[0-9A-Za-z]{8,}"#, in: result) { token in
            looksLikeCode(token) ? "[code removed]" : nil
        }
        // Long numbers, also when printed or read with spaces.
        result = replacing(#"\d[\d ]{6,}\d"#, in: result) { run in
            run.filter(\.isNumber).count >= 8 ? "[number removed]" : nil
        }
        return result
    }

    /// Mostly hex with several digits, like a piece of a PRD; never a date.
    static func looksLikeCode(_ token: String) -> Bool {
        if token.wholeMatch(of: /\d{1,4}-\d{1,2}-\d{1,4}/) != nil { return false }
        let characters = token.lowercased().filter { $0 != "-" }
        let hexLike = characters.filter { $0.isHexDigit || "lo".contains($0) }.count
        let digits = characters.filter(\.isNumber).count
        return characters.count >= 8 && digits >= 3 && Double(hexLike) >= 0.85 * Double(characters.count)
    }

    private static func replacing(_ pattern: String, in text: String, _ transform: (String) -> String?) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        var result = text
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let range = Range(match.range, in: result), let replacement = transform(String(result[range])) else { continue }
            result.replaceSubrange(range, with: replacement)
        }
        return result
    }

    public var json: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(self)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }
}
