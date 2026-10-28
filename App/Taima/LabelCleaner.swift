import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import Vision

/// Finds the bag or label in a photo, straightens it, crops the background
/// away and evens out the light, so the saved photo is tidy and the text
/// reads better. Runs on the phone; the original stays when nothing is found.
nonisolated enum LabelCleaner {
    struct Result {
        /// The straightened crop, best for reading.
        let image: UIImage
        let cropped: Bool
        /// What to keep as the photo. A crop smaller than most of the frame
        /// may be only the label panel, so the whole photo is kept instead.
        let photo: UIImage
    }

    /// Share of the frame a crop must cover to replace the photo.
    static let keepCropArea: CGFloat = 0.3

    private static let context = CIContext()


    static func clean(_ image: UIImage) -> Result {
        guard let cgImage = image.cgImage else { return Result(image: image, cropped: false, photo: image) }
        let input = CIImage(cgImage: cgImage)
        let whole = enhance(input).flatMap(render) ?? image
        guard let quad = findQuad(in: cgImage) else {
            return Result(image: whole, cropped: false, photo: whole)
        }
        let size = input.extent.size
        func point(_ p: CGPoint) -> CIVector { CIVector(x: p.x * size.width, y: p.y * size.height) }
        let correction = CIFilter.perspectiveCorrection()
        correction.inputImage = input
        correction.topLeft = point(quad.topLeft).cgPointValue
        correction.topRight = point(quad.topRight).cgPointValue
        correction.bottomLeft = point(quad.bottomLeft).cgPointValue
        correction.bottomRight = point(quad.bottomRight).cgPointValue
        guard let straightened = correction.outputImage, let cleaned = enhance(straightened), let output = render(cleaned) else {
            return Result(image: image, cropped: false, photo: image)
        }
        return Result(image: output, cropped: true, photo: area(quad) >= keepCropArea ? output : whole)
    }

    /// The outline of the bag or label: document segmentation first, then
    /// the largest clear rectangle. Too small or too thin outlines are ignored.
    private static func findQuad(in image: CGImage) -> VNRectangleObservation? {
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up)
        let document = VNDetectDocumentSegmentationRequest()
        let rectangles = VNDetectRectanglesRequest()
        rectangles.minimumSize = 0.25
        rectangles.maximumObservations = 4
        rectangles.minimumConfidence = 0.6
        rectangles.quadratureTolerance = 25
        try? handler.perform([document, rectangles])
        let candidates = (document.results ?? []) + (rectangles.results ?? []).sorted { area($0) > area($1) }
        return candidates.first { isPlausible($0, width: CGFloat(image.width), height: CGFloat(image.height)) }
    }

    /// An outline worth cropping to. Nearly the whole frame, a strip along
    /// an edge (three corners on the border) or an extreme shape means
    /// nothing real was found; the simulator's detector returns exactly such
    /// a strip for most photos.
    static func isPlausible(_ quad: VNRectangleObservation, width: CGFloat, height: CGFloat) -> Bool {
        let size = area(quad)
        guard quad.confidence >= 0.5, size > 0.12, size < 0.97 else { return false }
        let corners = [quad.topLeft, quad.topRight, quad.bottomLeft, quad.bottomRight]
        let onBorder = corners.filter { $0.x < 0.02 || $0.x > 0.98 || $0.y < 0.02 || $0.y > 0.98 }.count
        guard onBorder < 3 else { return false }
        let pixelWidth = (distance(quad.topLeft, quad.topRight) + distance(quad.bottomLeft, quad.bottomRight)) / 2 * width
        let pixelHeight = (distance(quad.topLeft, quad.bottomLeft) + distance(quad.topRight, quad.bottomRight)) / 2 * height
        let ratio = pixelWidth / max(pixelHeight, 1)
        return ratio > 0.3 && ratio < 3.5
    }

    private static func area(_ quad: VNRectangleObservation) -> CGFloat {
        let width = (distance(quad.topLeft, quad.topRight) + distance(quad.bottomLeft, quad.bottomRight)) / 2
        let height = (distance(quad.topLeft, quad.bottomLeft) + distance(quad.topRight, quad.bottomRight)) / 2
        return width * height
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

    /// Gentle cleanup: lifted shadows, a little contrast and sharpening.
    private static func enhance(_ image: CIImage) -> CIImage? {
        let shadows = CIFilter.highlightShadowAdjust()
        shadows.inputImage = image
        shadows.shadowAmount = 0.35
        shadows.highlightAmount = 0.95
        let controls = CIFilter.colorControls()
        controls.inputImage = shadows.outputImage
        controls.contrast = 1.08
        controls.saturation = 1.02
        let sharpen = CIFilter.sharpenLuminance()
        sharpen.inputImage = controls.outputImage
        sharpen.sharpness = 0.35
        return sharpen.outputImage
    }

    private static func render(_ image: CIImage) -> UIImage? {
        context.createCGImage(image, from: image.extent).map { UIImage(cgImage: $0) }
    }
}
