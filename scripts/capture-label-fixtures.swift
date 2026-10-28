import Foundation
import ImageIO
import Vision

// Usage: swift scripts/capture-label-fixtures.swift <output.json> <photos...>
// Text and boxes only. Review orphaned code fragments before committing.
struct Candidate: Codable { var text: String; var confidence: Double }
struct Box: Codable { var x: Double; var y: Double; var width: Double; var height: Double }
struct Line: Codable { var text: String; var box: Box; var confidence: Double; var alternatives: [Candidate] }
struct Code: Codable { var kind: String; var payload: String }
struct Capture: Codable { var id: String; var lines: [Line]; var codes: [Code] }

guard CommandLine.arguments.count >= 3 else {
    print("Usage: swift scripts/capture-label-fixtures.swift <output.json> <photos...>")
    exit(2)
}
let output = CommandLine.arguments[1]
var captures: [Capture] = []
for (index, path) in CommandLine.arguments.dropFirst(2).enumerated() {
    let syntheticID = String(format: "PRD-00000000-0000-4000-8000-%012d", index + 1)
    func anonymize(_ value: String) -> String {
        let regex = try! NSRegularExpression(pattern: #"PRD-[a-z0-9-]+"#, options: [.caseInsensitive])
        var result = value
        for match in regex.matches(in: value, range: NSRange(value.startIndex..., in: value)).reversed() {
            let token = (value as NSString).substring(with: match.range)
            let fake = Array(syntheticID)
            let replacement = token.enumerated().map { index, character -> Character in
                if index < 4 { return Array("PRD-")[index] }
                if character == "-" { return "-" }
                if character == "O" || character == "o" { return "O" }
                if !character.isHexDigit { return "Z" }
                return index < fake.count && fake[index] != "-" ? fake[index] : "0"
            }
            if let range = Range(match.range, in: result) { result.replaceSubrange(range, with: String(replacement)) }
        }
        return result
    }
    let text = VNRecognizeTextRequest()
    text.recognitionLevel = .accurate
    text.recognitionLanguages = ["nl-NL", "en-US"]
    text.usesLanguageCorrection = false
    let barcodes = VNDetectBarcodesRequest()
    try VNImageRequestHandler(url: URL(fileURLWithPath: path)).perform([text, barcodes])
    let lines = (text.results ?? []).compactMap { observation -> Line? in
        let candidates = observation.topCandidates(3)
        guard let first = candidates.first else { return nil }
        let box = observation.boundingBox
        return Line(text: anonymize(first.string), box: Box(x: box.minX, y: box.minY, width: box.width, height: box.height),
                    confidence: Double(first.confidence), alternatives: candidates.dropFirst().map {
                        Candidate(text: anonymize($0.string), confidence: Double($0.confidence))
                    })
    }
    let codes = (barcodes.results ?? []).compactMap { observation -> Code? in
        guard let payload = observation.payloadStringValue else { return nil }
        let kind: String = switch observation.symbology {
        case .qr, .microQR: "qr"
        case .ean13, .ean8: "ean"
        case .code128: "code128"
        default: "other"
        }
        return Code(kind: kind, payload: anonymize(payload))
    }
    captures.append(Capture(id: "capture-\(index + 1)", lines: lines, codes: codes))
}
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try encoder.encode(captures).write(to: URL(fileURLWithPath: output))
