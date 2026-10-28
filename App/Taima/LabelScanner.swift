import CoreVideo
import ImageIO
import TaimaCore
import Vision

/// On-device label reading with Vision. Nothing leaves the phone.
nonisolated enum LabelScanner {
    static func read(_ image: CGImage) -> LabelReading {
        read { VNImageRequestHandler(cgImage: image, orientation: $0) }.reading
    }

    /// One video frame. `characters` measures how much text was legible,
    /// which picks the clearest frame to keep as the photo.
    static func read(_ pixelBuffer: CVPixelBuffer, fast: Bool = false) -> (reading: LabelReading, characters: Int) {
        read(fast: fast) { VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: $0) }
    }

    private static func read(fast: Bool = false, handler: (CGImagePropertyOrientation) -> VNImageRequestHandler) -> (reading: LabelReading, characters: Int) {
        let result = recognizeWithFallback { recognize(handler($0), fast: fast) }
        return (LabelParser.parse(lines: result.lines, codes: result.codes), result.characters)
    }

    static func recognizeWithFallback(_ recognize: (CGImagePropertyOrientation) -> Recognition) -> Recognition {
        var best = recognize(.up)
        var codes = best.codes
        if best.characters < 20 {
            for orientation in [CGImagePropertyOrientation.right, .down] {
                if Task.isCancelled { break }
                let rotated = recognize(orientation)
                for code in rotated.codes where !codes.contains(code) { codes.append(code) }
                if rotated.characters > best.characters { best = rotated }
            }
        }
        best.codes = codes
        return best
    }

    struct Recognition {
        var lines: [RecognizedLine]
        var codes: [DetectedCode]
        var characters: Int { lines.map(\.text.count).reduce(0, +) }
    }

    private static func recognize(_ handler: VNImageRequestHandler, fast: Bool) -> Recognition {
        let text = VNRecognizeTextRequest()
        text.recognitionLevel = fast ? .fast : .accurate
        text.recognitionLanguages = ["nl-NL", "en-US"]
        // Strain names are not dictionary words; correction mangles them.
        text.usesLanguageCorrection = false
        let barcodes = VNDetectBarcodesRequest()
        try? handler.perform([text, barcodes])

        let lines = (text.results ?? []).compactMap { observation -> RecognizedLine? in
            let candidates = observation.topCandidates(3)
            guard let primary = candidates.first else { return nil }
            let box = observation.boundingBox
            return RecognizedLine(primary.string, x: box.minX, y: box.minY, width: box.width, height: box.height,
                                  confidence: Double(primary.confidence), alternatives: candidates.dropFirst().map {
                RecognizedCandidate($0.string, confidence: Double($0.confidence))
            })
        }
        let codes = (barcodes.results ?? []).compactMap { observation -> DetectedCode? in
            guard let payload = observation.payloadStringValue else { return nil }
            let kind: DetectedCode.Kind = switch observation.symbology {
            case .qr, .microQR: .qr
            case .ean13, .ean8: .ean
            case .code128: .code128
            default: .other
            }
            return DetectedCode(kind: kind, payload: payload)
        }
        return Recognition(lines: lines, codes: codes)
    }
}
