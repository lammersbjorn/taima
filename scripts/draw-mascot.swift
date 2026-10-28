// Draws Taima's mascot: a kawaii fan leaf in the spirit of Saiko's mushroom.
// Usage: swift scripts/draw-mascot.swift <icon.png> <mascot.png>
import AppKit

func render(size: Int, background: Bool, to path: String) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let cg = context.cgContext
    let scale = CGFloat(size) / 1024
    // Work in a 1024 canvas with y pointing down.
    cg.translateBy(x: 0, y: CGFloat(size))
    cg.scaleBy(x: scale, y: -scale)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
    func gradient(_ stops: [(UInt32, CGFloat, CGFloat)]) -> CGGradient {
        CGGradient(colorsSpace: space, colors: stops.map { color($0.0, $0.1) } as CFArray, locations: stops.map(\.2))!
    }

    if background {
        cg.drawLinearGradient(gradient([(0x10261B, 1, 0), (0x04100A, 1, 1)]), start: CGPoint(x: 512, y: 0), end: CGPoint(x: 512, y: 1024), options: [])
        cg.drawRadialGradient(gradient([(0x4ADE80, 0.38, 0), (0x4ADE80, 0.10, 0.6), (0x4ADE80, 0, 1)]),
                              startCenter: CGPoint(x: 512, y: 430), startRadius: 0, endCenter: CGPoint(x: 512, y: 430), endRadius: 470, options: [])
    }

    let hub = CGPoint(x: 512, y: 615)
    // (angle from straight up in degrees, length, width)
    let leaflets: [(CGFloat, CGFloat, CGFloat)] = [
        (0, 470, 150), (-30, 430, 140), (30, 430, 140), (-60, 360, 124), (60, 360, 124), (-90, 270, 104), (90, 270, 104)
    ]
    let leaves = CGMutablePath()
    var ribs: [(CGPoint, CGPoint)] = []
    for (degrees, length, width) in leaflets {
        let radians = degrees * .pi / 180
        let direction = CGPoint(x: sin(radians), y: -cos(radians))
        let center = CGPoint(x: hub.x + direction.x * length / 2, y: hub.y + direction.y * length / 2)
        var transform = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: radians)
        leaves.addPath(CGPath(ellipseIn: CGRect(x: -width / 2, y: -length / 2, width: width, height: length), transform: &transform))
        ribs.append((CGPoint(x: hub.x + direction.x * 120, y: hub.y + direction.y * 120),
                     CGPoint(x: hub.x + direction.x * (length - 70), y: hub.y + direction.y * (length - 70))))
    }

    // Soft shadow under the leaf.
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: 18), blur: 40, color: color(0x000000, 0.45))
    cg.addPath(leaves)
    cg.setFillColor(color(0x2FB36E))
    cg.fillPath()
    cg.restoreGState()

    cg.saveGState()
    cg.addPath(leaves)
    cg.clip()
    cg.drawLinearGradient(gradient([(0xB8F36B, 1, 0), (0x4CD47E, 1, 0.45), (0x17A39A, 1, 1)]),
                          start: CGPoint(x: 230, y: 160), end: CGPoint(x: 800, y: 700), options: [])
    cg.restoreGState()

    // Midribs, like the spots on Saiko's cap.
    cg.setLineCap(.round)
    cg.setLineWidth(16)
    cg.setStrokeColor(color(0xF3FFF5, 0.55))
    for (start, end) in ribs {
        cg.move(to: start)
        cg.addLine(to: end)
    }
    cg.strokePath()

    // Stem.
    let stem = CGPath(roundedRect: CGRect(x: 488, y: 680, width: 48, height: 170), cornerWidth: 24, cornerHeight: 24, transform: nil)
    cg.addPath(stem)
    cg.setFillColor(color(0x23986A))
    cg.fillPath()

    // The face sits on a round, pale body at the hub.
    let body = CGPath(ellipseIn: CGRect(x: hub.x - 150, y: hub.y - 132, width: 300, height: 264), transform: nil)
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: 10), blur: 24, color: color(0x0B3B22, 0.35))
    cg.addPath(body)
    cg.setFillColor(color(0xF2FDF4))
    cg.fillPath()
    cg.restoreGState()
    cg.saveGState()
    cg.addPath(body)
    cg.clip()
    cg.drawLinearGradient(gradient([(0xFAFFFB, 1, 0), (0xD9F5E1, 1, 1)]), start: CGPoint(x: 512, y: 508), end: CGPoint(x: 512, y: 772), options: [])
    cg.restoreGState()

    let ink = color(0x1D3A2A)
    for x in [hub.x - 64, hub.x + 64] {
        cg.drawRadialGradient(gradient([(0xF27BA8, 0.55, 0), (0xF27BA8, 0.3, 0.55), (0xF27BA8, 0, 1)]),
                              startCenter: CGPoint(x: x + (x < hub.x ? -26 : 26), y: hub.y + 52), startRadius: 0,
                              endCenter: CGPoint(x: x + (x < hub.x ? -26 : 26), y: hub.y + 52), endRadius: 52, options: [])
        cg.setFillColor(ink)
        cg.fillEllipse(in: CGRect(x: x - 27, y: hub.y - 27, width: 54, height: 54))
        cg.setFillColor(color(0xFFFFFF))
        cg.fillEllipse(in: CGRect(x: x + 1, y: hub.y - 20, width: 18, height: 18))
    }
    cg.setStrokeColor(ink)
    cg.setLineWidth(17)
    cg.move(to: CGPoint(x: hub.x - 32, y: hub.y + 44))
    cg.addQuadCurve(to: CGPoint(x: hub.x + 32, y: hub.y + 44), control: CGPoint(x: hub.x, y: hub.y + 76))
    cg.strokePath()

    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

let arguments = CommandLine.arguments
render(size: 1024, background: true, to: arguments[1])
render(size: 512, background: false, to: arguments[2])
