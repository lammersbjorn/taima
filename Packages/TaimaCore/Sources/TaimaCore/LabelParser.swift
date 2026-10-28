import Foundation

/// A rectangle in normalized image coordinates with the origin at the bottom
/// left, as Vision reports it.
public struct LabelBox: Hashable, Sendable, Codable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    var midY: Double { y + height / 2 }
    var maxX: Double { x + width }
    var maxY: Double { y + height }
}

public struct RecognizedLine: Hashable, Sendable, Codable {
    public var text: String
    public var box: LabelBox
    public var confidence: Double?
    public var alternatives: [RecognizedCandidate]

    public init(_ text: String, _ box: LabelBox, confidence: Double? = nil, alternatives: [RecognizedCandidate] = []) {
        self.text = text
        self.box = box
        self.confidence = confidence
        self.alternatives = Array(alternatives.prefix(2))
    }

    public init(_ text: String, x: Double, y: Double, width: Double, height: Double, confidence: Double? = nil, alternatives: [RecognizedCandidate] = []) {
        self.init(text, LabelBox(x: x, y: y, width: width, height: height), confidence: confidence, alternatives: alternatives)
    }

    private enum CodingKeys: String, CodingKey { case text, box, confidence, alternatives }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(try values.decode(String.self, forKey: .text), try values.decode(LabelBox.self, forKey: .box),
                  confidence: try values.decodeIfPresent(Double.self, forKey: .confidence),
                  alternatives: try values.decodeIfPresent([RecognizedCandidate].self, forKey: .alternatives) ?? [])
    }

}

public struct DetectedCode: Hashable, Sendable, Codable {
    public enum Kind: String, Sendable, Codable { case qr, ean, code128, other }
    public var kind: Kind
    public var payload: String

    public init(kind: Kind, payload: String) {
        self.kind = kind
        self.payload = payload
    }
}

public enum LabelField: String, CaseIterable, Sendable, Codable {
    case name, producer, strainType, thc, cbd, grams, harvestedOn, packedOn, bestBeforeOn, productID, sku, ean, leafletURL, form, unitCount
}

/// What the parser could read from one label. Nothing here is trusted until
/// the person saves it.
public struct LabelReading: Sendable, Equatable {
    public var name: String?
    public var producer: String?
    public var strainType: StrainType?
    public var thc: Potency?
    public var cbd: Potency?
    public var grams: Double?
    public var harvestedOn: Date?
    public var packedOn: Date?
    public var bestBeforeOn: Date?
    public var productID: String?
    public var sku: String?
    public var ean: String?
    public var leafletURL: String?
    public var form: ProductForm?
    public var unitCount: Int?
    /// Stable identifiers printed on the label (phone, domain, EAN company
    /// prefix, SKU prefix) used to remember which producer it came from.
    public var producerKeys: [String] = []
    public var text: String = ""
    /// Heuristic evidence, not a calibrated probability. Missing means unknown.
    public var confidence: [LabelField: FieldConfidence] = [:]

    public init() {}

    /// A reading carrying only codes, to derive producer keys for saved bags.
    public static func with(ean: String?, sku: String?) -> LabelReading {
        var reading = LabelReading()
        reading.ean = ean
        reading.sku = sku
        return reading
    }

    public var detectedFields: Set<LabelField> {
        var fields = Set<LabelField>()
        if name != nil { fields.insert(.name) }
        if producer != nil { fields.insert(.producer) }
        if strainType != nil { fields.insert(.strainType) }
        if thc != nil { fields.insert(.thc) }
        if cbd != nil { fields.insert(.cbd) }
        if grams != nil { fields.insert(.grams) }
        if harvestedOn != nil { fields.insert(.harvestedOn) }
        if packedOn != nil { fields.insert(.packedOn) }
        if bestBeforeOn != nil { fields.insert(.bestBeforeOn) }
        if productID != nil { fields.insert(.productID) }
        if sku != nil { fields.insert(.sku) }
        if ean != nil { fields.insert(.ean) }
        if leafletURL != nil { fields.insert(.leafletURL) }
        if form != nil { fields.insert(.form) }
        if unitCount != nil { fields.insert(.unitCount) }
        return fields
    }
}

/// Turns recognized text and barcodes from a Dutch regulated-cannabis bag
/// label into fields. Pure and deterministic so it is testable off-device.
public enum LabelParser {
    public static func parse(lines: [RecognizedLine], codes: [DetectedCode]) -> LabelReading {
        let lines = lines.map { line in
            RecognizedLine(normalize(line.text), line.box, confidence: line.confidence,
                           alternatives: line.alternatives.map { RecognizedCandidate(normalize($0.text), confidence: $0.confidence) })
        }.filter { !$0.text.isEmpty || !$0.alternatives.isEmpty }
        let groups = rowGroups(lines)
        let rows = groups.map(samples)
        var reading = LabelReading()
        reading.text = rows.compactMap { $0.first?.text }.joined(separator: "\n")
        readCodes(codes, into: &reading)

        func fill<Value: Equatable>(_ field: LabelField, _ path: WritableKeyPath<LabelReading, Value?>,
                                    _ match: (String) -> (Value, Double)?) {
            guard reading[keyPath: path] == nil, let result = extract(rows, match: match) else { return }
            reading[keyPath: path] = result.value
            reading.confidence[field] = result.confidence
        }
        fill(.productID, \.productID) { printedProductID(in: $0).map { ($0, 0.9) } }
        fill(.sku, \.sku) { firstMatch(skuPattern, in: $0).map { ($0, 0.95) } }
        fill(.thc, \.thc) { cannabinoid(in: $0, thc: true) }
        fill(.cbd, \.cbd) { cannabinoid(in: $0, thc: false) }
        fill(.grams, \.grams) { row in
            guard let value = weight(in: [row]) else { return nil }
            return (value, row.localizedCaseInsensitiveContains("gewicht") ? 1 : 0.9)
        }
        // Only an explicit decimal gram token is safe without a printed weight.
        // Codes such as PHMX-FLW-50G have no published unit/decimal mapping.
        if reading.grams == nil, let sku = reading.sku,
           let groups = captures(#"-(\d{1,2}[.,]\d{1,2})G$"#, in: sku, options: [.caseInsensitive]),
           let grams = decimal(groups[1]), grams > 0, grams <= 100 {
            reading.grams = grams
            let source = reading.confidence[.sku]
            reading.confidence[.grams] = FieldConfidence(source: .inferred, ocrConfidence: source?.ocrConfidence,
                                                        specificity: 0.6, usedAlternative: source?.usedAlternative ?? false)
        }
        for field in [LabelField.form, .unitCount, .grams] {
            let result = extract(rows) { row -> (LabelReading.Value, Double)? in
                var part = LabelReading()
                readForm([row], into: &part)
                return part.value(for: field).map { ($0, 0.95) }
            }
            guard let result else { continue }
            switch result.value {
            case .text(let value) where field == .form: reading.form = ProductForm(rawValue: value)
            case .count(let value): reading.unitCount = value
            case .number(let value): reading.grams = value
            default: continue
            }
            reading.confidence[field] = result.confidence
        }
        if reading.form != .preroll { reading.unitCount = nil; reading.confidence[.unitCount] = nil }
        for field in [LabelField.harvestedOn, .packedOn, .bestBeforeOn] {
            if let result = extract(rows, match: { row -> (Date, Double)? in
                var part = LabelReading()
                readDates([row], into: &part)
                let date = switch field {
                case .harvestedOn: part.harvestedOn
                case .packedOn: part.packedOn
                default: part.bestBeforeOn
                }
                return date.map { ($0, hasDateLabel(row) ? 1 : 0.65) }
            }) {
                switch field {
                case .harvestedOn: reading.harvestedOn = result.value
                case .packedOn: reading.packedOn = result.value
                default: reading.bestBeforeOn = result.value
                }
                reading.confidence[field] = result.confidence
            }
        }
        // A date beneath a standalone heading, in the same column.
        for (index, row) in rows.enumerated() where index + 1 < rows.count {
            guard let heading = row.first?.text, hasDateLabel(heading), dates(in: heading).isEmpty,
                  let next = rows[index + 1].first, dates(in: next.text).count == 1,
                  !hasDateLabel(next.text),
                  let headingLine = groups[index].first, let valueLine = groups[index + 1].first,
                  abs(headingLine.box.x - valueLine.box.x) < 0.08,
                  headingLine.box.y - valueLine.box.maxY < 2 * headingLine.box.height else { continue }
            var part = LabelReading()
            readDates([heading + " " + next.text], into: &part)
            for field in [LabelField.harvestedOn, .packedOn, .bestBeforeOn] where reading.value(for: field) == nil {
                if case .date(let date) = part.value(for: field) {
                    if field == .harvestedOn { reading.harvestedOn = date }
                    else if field == .packedOn { reading.packedOn = date }
                    else { reading.bestBeforeOn = date }
                    reading.confidence[field] = FieldConfidence(ocrConfidence: minimumConfidence(groups[index] + groups[index + 1]),
                                                                specificity: 0.8)
                }
            }
        }

        let titleLines = lines.map { preferredNameCandidate($0, sku: reading.sku) }
        let title = nameGroup(from: titleLines)
        reading.name = title.isEmpty ? nil : cleanName(title.map(\.text).joined(separator: " "))
        if reading.name?.isEmpty == true { reading.name = nil }
        if reading.name != nil {
            let usedAlternative = title.contains { selected in
                lines.contains { $0.box == selected.box && $0.text != selected.text }
            }
            reading.confidence[.name] = FieldConfidence(ocrConfidence: minimumConfidence(title), specificity: 0.8,
                                                       usedAlternative: usedAlternative)
        }
        reading.strainType = reading.name.flatMap(strainType(in:))
        if reading.strainType != nil { reading.confidence[.strainType] = reading.confidence[.name] }
        reading.producerKeys = producerKeys(lineTexts: lines.map(\.text), reading: reading)
        let sorted = lines.sorted { $0.box.midY > $1.box.midY }
        let labelledGrower = GrowerDirectory.labelledGrower(in: groupIntoRows(lines))
        if let result = extract(rows, match: { row -> (String, Double)? in
            if let grower = GrowerDirectory.labelledGrower(in: [row]) { return (grower, 1) }
            return GrowerDirectory.match(keys: [], text: row).map { ($0, 0.9) }
        }), labelledGrower == nil || labelledGrower == result.value {
            reading.producer = result.value
            reading.confidence[.producer] = result.confidence
        } else if let grower = labelledGrower
            ?? GrowerDirectory.match(keys: reading.producerKeys, text: reading.text)
            ?? producer(from: sorted) {
            reading.producer = grower
            let supporting = sorted.filter { line in
                GrowerDirectory.labelledGrower(in: [line.text]) != nil
                    || GrowerDirectory.match(keys: producerKeys(lineTexts: [line.text], reading: LabelReading()), text: line.text) == grower
            }
            if supporting.isEmpty, let source = reading.confidence[.ean] {
                reading.confidence[.producer] = FieldConfidence(source: .inferred, ocrConfidence: source.score, specificity: 0.8)
            } else {
                reading.confidence[.producer] = FieldConfidence(ocrConfidence: minimumConfidence(supporting), specificity: 0.9)
            }
        }
        return reading
    }

    private struct Sample {
        var text: String
        var confidence: Double?
        var alternative = false

        func evidence(specificity: Double, ambiguous: Bool = false) -> FieldConfidence {
            FieldConfidence(ocrConfidence: confidence, specificity: specificity,
                            usedAlternative: alternative, isAmbiguous: ambiguous)
        }
    }

    private static func minimumConfidence(_ lines: [RecognizedLine]) -> Double? {
        guard !lines.isEmpty, lines.allSatisfy({ $0.confidence != nil }) else { return nil }
        return lines.compactMap(\.confidence).min()
    }

    private static func samples(_ lines: [RecognizedLine]) -> [Sample] {
        var variants: [(lines: [RecognizedLine], rank: Int)] = [([], 0)]
        for line in lines.sorted(by: { $0.box.x < $1.box.x }) {
            let choices = [RecognizedLine(line.text, line.box, confidence: line.confidence)] + line.alternatives.map {
                RecognizedLine($0.text, line.box, confidence: $0.confidence)
            }
            let expanded = variants.flatMap { variant in
                choices.enumerated().map { (lines: variant.lines + [$0.element], rank: variant.rank + $0.offset) }
            }
            // Bound combinations for dense rows, while allowing both a label
            // and its value to be rescued by alternate observations.
            variants = expanded.enumerated().sorted {
                $0.element.rank == $1.element.rank ? $0.offset < $1.offset : $0.element.rank < $1.element.rank
            }.prefix(27).map(\.element)
        }
        return variants.map {
            Sample(text: $0.lines.map(\.text).joined(separator: " "), confidence: minimumConfidence($0.lines), alternative: $0.rank > 0)
        }
    }

    private static func extract<Value: Equatable>(_ rows: [[Sample]], match: (String) -> (Value, Double)?)
        -> (value: Value, confidence: FieldConfidence)? {
        var best: (value: Value, confidence: FieldConfidence)?
        for row in rows {
            let matches = row.compactMap { sample -> (Value, Double, Sample)? in
                match(sample.text).map { ($0.0, $0.1, sample) }
            }
            guard let selected = matches.first else { continue }
            let ambiguous = matches.dropFirst().contains {
                $0.0 != selected.0 && ($0.2.confidence ?? 0.65) >= (selected.2.confidence ?? 0.65) - 0.15
            }
            let evidence = selected.2.evidence(specificity: selected.1, ambiguous: ambiguous)
            if best == nil || evidence.specificity > best!.confidence.specificity {
                best = (selected.0, evidence)
            }
        }
        return best
    }

    // MARK: - Text clean-up

    /// Vision sometimes returns Cyrillic look-alikes on Latin labels.
    private static let lookAlikes: [Character: Character] = [
        "А": "A", "В": "B", "С": "C", "Е": "E", "Н": "H", "К": "K", "М": "M", "О": "O", "Р": "P", "Т": "T", "Х": "X",
        "а": "a", "с": "c", "е": "e", "о": "o", "р": "p", "х": "x", "т": "t", "г": "r"
    ]

    static func normalize(_ text: String) -> String {
        String(text.map { lookAlikes[$0] ?? $0 })
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Joins observations that share a baseline, left to right, so a value in
    /// a separate column lands next to its label ("THC" ... "24%").
    static func groupIntoRows(_ lines: [RecognizedLine]) -> [String] {
        rowGroups(lines).map { $0.sorted { $0.box.x < $1.box.x }.map(\.text).joined(separator: " ") }
    }

    private static func rowGroups(_ lines: [RecognizedLine]) -> [[RecognizedLine]] {
        var rows: [[RecognizedLine]] = []
        for line in lines.sorted(by: { $0.box.midY > $1.box.midY }) {
            if let index = rows.lastIndex(where: { row in
                guard let first = row.first else { return false }
                return abs(first.box.midY - line.box.midY) < 0.65 * min(first.box.height, line.box.height)
                    && !row.contains { min($0.box.maxX, line.box.maxX) - max($0.box.x, line.box.x) > 0.2 * min($0.box.width, line.box.width) }
            }) {
                rows[index].append(line)
            } else { rows.append([line]) }
        }
        return rows
    }

    // MARK: - Codes

    private static let productIDPattern = #"PRD-[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"#
    private static let skuPattern = #"(?<![\w-])(?!PRD-)[A-Z]{2,6}(?:-[A-Z0-9]{1,10}(?:[.,][0-9]{1,2}[A-Z]*)?){1,3}(?![\w.-])"#

    /// OCR reads 0 as O inside printed codes; the UUID shape decides.
    static func printedProductID(in text: String) -> String? {
        let loose = #"PRD-[0-9a-fA-FoO]{8}-[0-9a-fA-FoO]{4}-[0-9a-fA-FoO]{4}-[0-9a-fA-FoO]{4}-[0-9a-fA-FoO]{12}"#
        guard let match = firstMatch(loose, in: text) else { return nil }
        let fixed = "PRD-" + match.dropFirst(4).replacingOccurrences(of: "o", with: "0").replacingOccurrences(of: "O", with: "0")
        return firstMatch(productIDPattern, in: fixed)?.lowercased()
    }

    /// GTIN/EAN modulo-10 check: weights 3 and 1 from the right, excluding the check digit.
    public static func isValidGTIN(_ digits: String) -> Bool {
        let values = digits.compactMap(\.wholeNumberValue)
        guard values.count == digits.count, [8, 12, 13, 14].contains(values.count), let check = values.last else { return false }
        let sum = values.dropLast().reversed().enumerated().reduce(0) { total, item in
            total + item.element * (item.offset.isMultiple(of: 2) ? 3 : 1)
        }
        return (10 - sum % 10) % 10 == check
    }

    private static func readCodes(_ codes: [DetectedCode], into reading: inout LabelReading) {
        for code in codes {
            let before = reading.detectedFields
            let payload = code.payload.trimmingCharacters(in: .whitespacesAndNewlines)
            if let id = firstMatch(productIDPattern, in: payload) {
                reading.productID = reading.productID ?? id.lowercased()
            } else if payload.lowercased().hasPrefix("http") {
                reading.leafletURL = reading.leafletURL ?? payload
            } else if code.kind == .ean, payload.allSatisfy(\.isNumber), isValidGTIN(payload) {
                reading.ean = reading.ean ?? payload
            } else if code.kind == .code128 || code.kind == .other, !payload.isEmpty {
                reading.sku = reading.sku ?? payload
            }
            for field in reading.detectedFields.subtracting(before) {
                reading.confidence[field] = FieldConfidence(source: .barcode)
            }
        }
    }

    // MARK: - Potency and weight

    private static let numberPattern = #"\d{1,2}(?:[.,]\d{1,2})?"#
    private static let weightPattern = #"(?<![\w.,:–-])(\d{1,3}(?:[.,]\d{1,2})?)\s*(?:gram|gr[a-z]{1,3}|gr\.?|g)(?![A-Za-z0-9])"#

    private static func cannabinoid(in row: String, thc: Bool) -> (Potency, Double)? {
        let label = thc ? #"(?:THC(?:[- ]?totaal)?|THCA|HC)"# : #"(?:CBD|C8D|C80|BD)"#
        // Text recognition sometimes returns "<" as a look-alike.
        let value = "(<|≤|‹|«|〈|⟨)?\\s*(" + numberPattern + ")(?:\\s*[-–]\\s*(" + numberPattern + "))?\\s*%"
        let before = "(?<![A-Za-z])" + label + #"\b\s*%?\s*[:.]?\s*"# + value
        let after = "(?<![\\d.,-])" + value + "\\s*" + label + #"\b"#
        guard let groups = captures(before, in: row, options: [.caseInsensitive])
            ?? captures(after, in: row, options: [.caseInsensitive]),
              let first = decimal(groups[2]), first <= 100 else { return nil }
        let upper = groups[3].isEmpty ? first : decimal(groups[3])
        guard let upper, upper >= first, upper <= 100, groups[3].isEmpty || groups[1].isEmpty else { return nil }
        let matched = groups[0].lowercased()
        let basis: Potency.Basis? = matched.contains("thca") ? .thca : matched.contains("totaal") ? .totalTHC : nil
        let specific = matched.contains(thc ? "thc" : "cbd") ? 1.0 : 0.8
        return (Potency(percent: upper, isUpperBound: !groups[1].isEmpty,
                        lowerBound: groups[3].isEmpty ? nil : first, basis: basis), basis == .thca ? 0.75 : specific)
    }

    private static func weight(in rows: [String]) -> Double? {
        let ordered = rows.filter { $0.localizedCaseInsensitiveContains("gewicht") } + rows
        for row in ordered {
            if let groups = captures(weightPattern, in: row, options: [.caseInsensitive]),
               let grams = decimal(groups[1]), grams > 0, grams <= 100 {
                return grams
            }
        }
        return nil
    }

    // MARK: - Prerolls and jars

    private static let packPattern = #"(?i)(?<![\w.,])(\d{1,2})\s*[x×]\s*(\d(?:[.,]\d{1,2})?)\s*(?:gram|gr\.?|g)(?![a-z])"#
    private static let countPattern = #"(?i)(?<![\w.,])(\d{1,2})\s*(?:stuks|stuk|st\.|pcs|pre-?rolls?|joints?)(?![a-z])"#

    /// Prerolls print a count ("3 x 0,5 g", "5 stuks"); jars say pot or jar.
    static func readForm(_ rows: [String], into reading: inout LabelReading) {
        let text = rows.joined(separator: " ")
        if let groups = captures(packPattern, in: text), let count = Int(groups[1]), let each = decimal(groups[2]), count > 0, each > 0, Double(count) * each <= 100 {
            reading.form = .preroll
            reading.unitCount = count
            // The pack total; "3 x 0,5 g" must not read as 3 g or 0,5 g.
            reading.grams = (Double(count) * each * 100).rounded() / 100
        }
        if reading.unitCount == nil, let groups = captures(countPattern, in: text), let count = Int(groups[1]), count > 0 {
            reading.unitCount = count
            reading.form = .preroll
        }
        if reading.form == nil, text.range(of: #"(?i)\bpre[- ]?rolls?\b|\bjoints?\b"#, options: .regularExpression) != nil {
            reading.form = .preroll
        } else if reading.form == nil, text.range(of: #"(?i)\b(?:hasj|hash|hashish|hasjiesj)\b"#, options: .regularExpression) != nil {
            reading.form = .hash
        } else if reading.form == nil, text.range(of: #"(?i)\b(?:potje|pot|jar)\b"#, options: .regularExpression) != nil {
            reading.form = .jar
        }
        if reading.form != .preroll { reading.unitCount = nil }
    }

    // MARK: - Dates

    private static let datePattern = #"(?<!\d)(?:\d{4}-\d{1,2}-\d{1,2}|\d{1,2}\s?[-./ ]\s?\d{1,2}\s?[-./ ]\s?\d{4}|\d{1,2}\s+[a-zA-Z]+\.?\s+\d{4})(?!\d)"#
    private static let harvestLabel = #"\b(?:g[eo0]{0,3}gst[a-z]*|oogst[a-z]*|geproduceerd)\b(?!\s+door)"#
    private static let packedLabel = #"\b[vh]erpa[a-z]{0,3}k[a-z]*\b(?!\s+door)"#
    private static let bestBeforeLabel = #"\b(?:houdbaar\s+tot|ten\s+minste\s+houdbaar\s+tot|THT)\b"#
    private static var dateLabels: String { "(?:" + harvestLabel + "|" + packedLabel + "|" + bestBeforeLabel + ")" }

    private static func hasDateLabel(_ text: String) -> Bool {
        text.range(of: dateLabels, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func readDates(_ rows: [String], into reading: inout LabelReading) {
        for row in rows {
            guard let regex = try? NSRegularExpression(pattern: dateLabels, options: [.caseInsensitive]) else { continue }
            let labels = regex.matches(in: row, range: NSRange(row.startIndex..., in: row))
            for (index, match) in labels.enumerated() {
                let end = index + 1 < labels.count ? labels[index + 1].range.location : (row as NSString).length
                let tail = (row as NSString).substring(with: NSRange(location: NSMaxRange(match.range), length: end - NSMaxRange(match.range)))
                guard let date = dates(in: tail).first else { continue }
                let label = (row as NSString).substring(with: match.range)
                if label.range(of: bestBeforeLabel, options: [.regularExpression, .caseInsensitive]) != nil {
                    reading.bestBeforeOn = reading.bestBeforeOn ?? date
                } else if label.range(of: packedLabel, options: [.regularExpression, .caseInsensitive]) != nil {
                    reading.packedOn = reading.packedOn ?? date
                } else { reading.harvestedOn = reading.harvestedOn ?? date }
            }
        }
        guard reading.harvestedOn == nil, reading.packedOn == nil else { return }
        for row in rows where !hasDateLabel(row) {
            let found = dates(in: row)
            if found.count >= 2 {
                reading.harvestedOn = found.first
                reading.packedOn = found.last
                return
            }
        }
    }

    static func dates(in text: String) -> [Date] {
        let months = ["jan", "feb", "mrt", "apr", "mei", "jun", "jul", "aug", "sep", "okt", "nov", "dec"]
        let fullMonths = ["januari", "februari", "maart", "april", "mei", "juni", "juli", "augustus", "september", "oktober", "november", "december"]
        guard let regex = try? NSRegularExpression(pattern: datePattern) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            let token = (text as NSString).substring(with: match.range).lowercased()
            let parts = token.split { "-./ ".contains($0) }.map(String.init)
            guard parts.count == 3 else { return nil }
            let iso = parts[0].count == 4
            guard let day = Int(parts[iso ? 2 : 0]), let year = Int(parts[iso ? 0 : 2]),
                  let month = Int(parts[1]) ?? months.firstIndex(of: parts[1]).map({ $0 + 1 })
                    ?? fullMonths.firstIndex(of: parts[1]).map({ $0 + 1 }),
                  (1...31).contains(day), (1...12).contains(month), (2000...2100).contains(year) else { return nil }
            let components = DateComponents(year: year, month: month, day: day, hour: 12)
            guard let date = Calendar.taima.date(from: components), Calendar.taima.component(.day, from: date) == day else { return nil }
            return date
        }
    }

    // MARK: - Name and producer

    private static let fieldWords = [
        "thc", "cbd", "gewicht", "geoogst", "verpakt", "track", "trace", "bijsluiter", "kinderen",
        "bereik", "tel", "www", "@", "prd-", "organics", ".nl", "t&t", "b.v.", "datum", "geproduceerd",
        "houdbaar", "tht", "stuks", "teler", "geteeld", "producer", "grower", "vervaardigd", "inhoud"
    ]

    private static func isFieldLine(_ text: String) -> Bool {
        let lower = text.lowercased()
        if fieldWords.contains(where: lower.contains) { return true }
        if ["cannabis", "wiet", "bloemen", "flower"].contains(lower) { return true }
        if firstMatch(datePattern, in: text) != nil { return true }
        if text.contains("%") || hasDateLabel(text) { return true }
        if weight(in: [text]) != nil && cleanName(text).filter(\.isLetter).count < 3 { return true }
        if text.range(of: #"^\d{1,2}[:.]\d{2}\b"#, options: .regularExpression) != nil { return true }
        if firstMatch(skuPattern, in: text) == text { return true }
        let letters = text.filter(\.isLetter).count
        return letters < 3 || letters * 2 < text.count
    }

    /// The product name is the largest printed text; a title split over two
    /// lines of the same size is joined.
    static func name(from lines: [RecognizedLine]) -> String? {
        let text = nameGroup(from: lines).map(\.text).joined(separator: " ")
        let cleaned = cleanName(text)
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func preferredNameCandidate(_ line: RecognizedLine, sku: String?) -> RecognizedLine {
        func quality(_ text: String) -> Int {
            let text = cleanName(text).lowercased()
            var score = text.range(of: #"\bmix\b"#, options: .regularExpression) == nil ? 0 : 1
            if let sku, sku.lowercased().replacingOccurrences(of: "-", with: "").contains(text.replacingOccurrences(of: " ", with: "")) { score += 2 }
            return score
        }
        let primary = quality(line.text)
        if let candidate = line.alternatives.first(where: {
            $0.confidence >= (line.confidence ?? 0.65) - 0.15 && quality($0.text) > primary
        }) {
            return RecognizedLine(candidate.text, line.box, confidence: candidate.confidence)
        }
        return line
    }

    private static func nameGroup(from lines: [RecognizedLine]) -> [RecognizedLine] {
        let candidates = lines.filter { $0.box.x > 0.01 && $0.box.maxX < 0.99 && !isFieldLine($0.text) }
        func brandOnly(_ line: RecognizedLine) -> Bool {
            let name = cleanName(line.text).lowercased()
            return name == "cog" || GrowerDirectory.known.contains { $0.aliases.contains(name) }
        }
        let titles = candidates.filter { !brandOnly($0) }
        guard let primary = (titles.isEmpty ? candidates : titles).max(by: { $0.box.height < $1.box.height }) else { return [] }
        var group = [primary]
        var changed = true
        while changed && group.count < 4 {
            changed = false
            for candidate in candidates where !group.contains(candidate) {
                let size = primary.box.height
                guard brandOnly(candidate) || (candidate.box.height >= 0.7 * size && candidate.box.height <= 1.8 * size) else { continue }
                let adjacent = group.contains { member in
                    let gap = max(member.box.y - candidate.box.maxY, candidate.box.y - member.box.maxY)
                    let aligned = abs(member.box.x - candidate.box.x) < 0.06
                        || abs(member.box.x + member.box.width / 2 - candidate.box.x - candidate.box.width / 2) < 0.04
                    return gap >= -0.3 * min(member.box.height, candidate.box.height) && gap < 1.8 * size && aligned
                }
                if adjacent { group.append(candidate); changed = true }
            }
        }
        return group.sorted { $0.box.midY > $1.box.midY }
    }

    public static func cleanName(_ text: String) -> String {
        var name = text.replacingOccurrences(
            of: #"\s*\d+(?:[.,]\d+)?\s*(?:gram|gr[a-z]{1,3}|gr|g)\.?\s*$"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        // "C O G Amnesia" -> "COG Amnesia".
        name = name.replacingOccurrences(
            of: #"\b([A-Z])\s(?=[A-Z]\b)"#,
            with: "$1",
            options: .regularExpression
        )
        name = name.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        // OCR reads the O in Canadelaar's spaced "C O G" brand as Q or 0.
        name = name.replacingOccurrences(of: #"^C[Q0]G\b"#, with: "COG", options: .regularExpression)
        return name.trimmingCharacters(in: CharacterSet(charactersIn: " :;'\"`.,-_|"))
    }

    private static let producerWords = ["organics", "farms", "farm", "kwekerij", "b.v.", "bv", "growers", "cannabis co", "holland"]

    static func producer(from lines: [RecognizedLine]) -> String? {
        for line in lines {
            let words = line.text.lowercased().split(separator: " ").map(String.init)
            if words.contains(where: { producerWords.contains($0) }), line.text.count <= 40 {
                return cleanName(line.text)
            }
        }
        for line in lines {
            if let domain = domain(in: line.text) {
                let stem = domain.split(separator: ".").first.map(String.init) ?? domain
                return stem.prefix(1).uppercased() + stem.dropFirst()
            }
        }
        return nil
    }

    static func domain(in text: String) -> String? {
        guard let groups = captures(#"(?:www\.|@)([a-z0-9-]+\.[a-z]{2,})"#, in: text.lowercased()) else { return nil }
        // OCR reads ".nl" as ".ni" often enough to matter.
        return groups[1].replacingOccurrences(of: #"\.ni$"#, with: ".nl", options: .regularExpression)
    }

    static func strainType(in name: String) -> StrainType? {
        let lower = name.lowercased()
        return StrainType.allCases.first { lower.contains($0.rawValue) }
    }

    // MARK: - Producer keys

    public static func producerKeys(lineTexts: [String], reading: LabelReading) -> [String] {
        var keys: [String] = []
        for line in lineTexts {
            if let groups = captures(#"\bte[l.:]?[\s:.]*(\+?[\d][\d\s-]{8,})"#, in: line, options: [.caseInsensitive]) {
                // The last nine digits survive both "+31 181" and "0181" forms.
                let digits = groups[1].filter(\.isNumber)
                if digits.count >= 9 { keys.append("tel:" + digits.suffix(9)) }
            }
            if let domain = domain(in: line) { keys.append("domain:" + domain) }
        }
        if let ean = reading.ean, ean.count == 13 { keys.append("ean:" + ean.prefix(7)) }
        if let sku = reading.sku, let prefix = sku.split(separator: "-").first, sku.contains("-") {
            keys.append("sku:" + prefix.uppercased())
        }
        var seen = Set<String>()
        return keys.filter { seen.insert($0).inserted }
    }

    // MARK: - Regex helpers

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let range = text.range(of: pattern, options: .regularExpression) else { return nil }
        return String(text[range])
    }

    private static func captures(_ pattern: String, in text: String, options: NSRegularExpression.Options = []) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
        else { return nil }
        return (0..<match.numberOfRanges).map { index in
            Range(match.range(at: index), in: text).map { String(text[$0]) } ?? ""
        }
    }

    private static func decimal(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: "."))
    }
}
