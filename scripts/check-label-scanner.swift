import CoreGraphics
import CoreText
import Foundation
import ImageIO
import TaimaCore

// Compile alongside App/Taima/LabelScanner.swift, linking TaimaCore.
@main struct LabelScannerCheck {
    static func main() {
        func recognition(_ text: String, codes: [DetectedCode] = []) -> LabelScanner.Recognition {
            .init(lines: text.isEmpty ? [] : [RecognizedLine(text, x: 0.1, y: 0.5, width: 0.8, height: 0.05)], codes: codes)
        }
        var calls: [CGImagePropertyOrientation] = []
        let barcode = DetectedCode(kind: .code128, payload: "AB-FLW-0.5G")
        let selected = LabelScanner.recognizeWithFallback { orientation in
            calls.append(orientation)
            switch orientation {
            case .up: return recognition("", codes: [barcode])
            case .right: return recognition("THC 24% Moon Garden 1 gram")
            default: return recognition("noise")
            }
        }
        precondition(calls == [.up, .right, .down])
        precondition(selected.lines.first?.text == "THC 24% Moon Garden 1 gram" && selected.codes == [barcode])
        calls = []
        _ = LabelScanner.recognizeWithFallback { orientation in
            calls.append(orientation)
            return recognition("Moon Garden THC 24% 1 gram")
        }
        precondition(calls == [.up])

        let image = labelImage()
        for angle in [0.0, Double.pi / 2, Double.pi] {
            let reading = LabelScanner.read(rotate(image, angle: angle))
            precondition(reading.thc?.percent == 24, "THC at rotation \(angle): \(reading.text)")
            precondition(reading.grams == 1, "Weight at rotation \(angle): \(reading.text)")
            precondition(reading.name == "Moon Garden", "Name at rotation \(angle): \(reading.text)")
            precondition(reading.confidence[.thc]?.ocrConfidence != nil)
        }
        print("Scanner fallback control flow and real Vision at 0, 90 and 180 degrees passed.")
    }

    static func labelImage() -> CGImage {
        let context = CGContext(data: nil, width: 1200, height: 1200, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1200, height: 1200))
        for (text, y, size) in [("Moon Garden", 850.0, 80.0), ("THC 24%", 650.0, 55.0), ("Gewicht 1 gram", 450.0, 55.0)] {
            let string = NSAttributedString(string: text, attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica" as CFString, size, nil),
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1)
            ])
            context.textPosition = CGPoint(x: 180, y: y)
            CTLineDraw(CTLineCreateWithAttributedString(string), context)
        }
        return context.makeImage()!
    }

    static func rotate(_ image: CGImage, angle: Double) -> CGImage {
        let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.translateBy(x: 600, y: 600)
        context.rotate(by: angle)
        context.draw(image, in: CGRect(x: -600, y: -600, width: 1200, height: 1200))
        return context.makeImage()!
    }
}
