// Draws Taima's discreet icon: a plain notes-style mark with no leaf.
// Usage: swift scripts/draw-discreet-icon.swift <icon.png>
import AppKit

let size = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let context = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
let cg = context.cgContext
let space = CGColorSpace(name: CGColorSpace.sRGB)!
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: a) }
let gradient = CGGradient(colorsSpace: space, colors: [color(0.36, 0.40, 0.45), color(0.22, 0.25, 0.29)] as CFArray, locations: [0, 1])!
cg.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 0, y: 0), options: [])
// A page with three lines.
let page = CGRect(x: 262, y: 212, width: 500, height: 600)
cg.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: color(0, 0, 0, 0.3))
cg.addPath(CGPath(roundedRect: page, cornerWidth: 64, cornerHeight: 64, transform: nil))
cg.setFillColor(color(0.97, 0.97, 0.96))
cg.fillPath()
cg.setShadow(offset: .zero, blur: 0, color: nil)
cg.setFillColor(color(0.62, 0.66, 0.70))
for (index, width) in [300.0, 360.0, 240.0].enumerated() {
    cg.addPath(CGPath(roundedRect: CGRect(x: 332, y: 650 - Double(index) * 120, width: width, height: 44), cornerWidth: 22, cornerHeight: 22, transform: nil))
    cg.fillPath()
}
context.flushGraphics()
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
