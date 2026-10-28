import Foundation

public struct RecognizedCandidate: Hashable, Sendable, Codable {
    public var text: String
    public var confidence: Double

    public init(_ text: String, confidence: Double) {
        self.text = text
        self.confidence = confidence
    }
}

/// Evidence for a field, kept separate from the editable value.
public struct FieldConfidence: Sendable, Equatable {
    public enum Source: Sendable, Equatable { case ocr, barcode, inferred }
    public var source: Source
    public var ocrConfidence: Double?
    public var specificity: Double
    public var usedAlternative: Bool
    public var isAmbiguous: Bool
    public var agreement: Double

    public init(source: Source = .ocr, ocrConfidence: Double? = nil, specificity: Double = 1,
                usedAlternative: Bool = false, isAmbiguous: Bool = false, agreement: Double = 1) {
        self.source = source
        self.ocrConfidence = ocrConfidence
        self.specificity = specificity
        self.usedAlternative = usedAlternative
        self.isAmbiguous = isAmbiguous
        self.agreement = agreement
    }

    public var score: Double {
        let recognition = source == .barcode ? 0.99 : Self.unit(ocrConfidence ?? 0.65)
        return recognition * Self.unit(specificity) * (usedAlternative ? 0.9 : 1)
            * (isAmbiguous ? 0.65 : 1) * Self.unit(agreement)
    }

    public var needsReview: Bool { score < 0.75 || isAmbiguous }

    private static func unit(_ value: Double) -> Double { value.isFinite ? min(1, max(0, value)) : 0 }
}

extension LabelReading {
    enum Value: Hashable, Sendable {
        case text(String), number(Double), date(Date), potency(Potency), count(Int)
    }

    func value(for field: LabelField) -> Value? {
        switch field {
        case .name: name.map(Value.text)
        case .producer: producer.map(Value.text)
        case .strainType: strainType.map { .text($0.rawValue) }
        case .thc: thc.map(Value.potency)
        case .cbd: cbd.map(Value.potency)
        case .grams: grams.map(Value.number)
        case .harvestedOn: harvestedOn.map(Value.date)
        case .packedOn: packedOn.map(Value.date)
        case .bestBeforeOn: bestBeforeOn.map(Value.date)
        case .productID: productID.map(Value.text)
        case .sku: sku.map(Value.text)
        case .ean: ean.map(Value.text)
        case .leafletURL: leafletURL.map(Value.text)
        case .form: form.map { .text($0.rawValue) }
        case .unitCount: unitCount.map(Value.count)
        }
    }

    mutating func set(_ value: Value, for field: LabelField) {
        switch (field, value) {
        case (.name, .text(let text)): name = text
        case (.producer, .text(let text)): producer = text
        case (.strainType, .text(let raw)): strainType = StrainType(rawValue: raw)
        case (.thc, .potency(let value)): thc = value
        case (.cbd, .potency(let value)): cbd = value
        case (.grams, .number(let value)): grams = value
        case (.harvestedOn, .date(let value)): harvestedOn = value
        case (.packedOn, .date(let value)): packedOn = value
        case (.bestBeforeOn, .date(let value)): bestBeforeOn = value
        case (.productID, .text(let text)): productID = text
        case (.sku, .text(let text)): sku = text
        case (.ean, .text(let text)): ean = text
        case (.leafletURL, .text(let text)): leafletURL = text
        case (.form, .text(let raw)): form = ProductForm(rawValue: raw)
        case (.unitCount, .count(let value)): unitCount = value
        default: break
        }
    }

}
