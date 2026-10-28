import SwiftUI

/// Taima's design tokens, after Saiko Next's visual language: a calm
/// neutral page, opaque cells, one green accent for what can be tapped, and
/// the person's own numbers in SF Rounded. Colour lives in content; the
/// chrome is system Liquid Glass.
enum Theme {
    private static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        func color(_ hex: UInt32) -> UIColor {
            UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        }
        return Color(UIColor { $0.userInterfaceStyle == .dark ? color(dark) : color(light) })
    }

    // MARK: Surfaces and text (contrast measured like Saiko Next's tokens)

    /// Grouped page: neutral in light mode, pure black in dark mode.
    static let page = dynamic(0xF2F2F4, 0x000000)
    /// Cards and cells, always opaque and lighter than the page.
    static let cell = dynamic(0xFFFFFF, 0x1A1A1C)
    /// A panel inside a cell: chips, tracks, nested blocks.
    static let cellRaised = dynamic(0xF2F2F5, 0x2A2A2E)
    /// Secondary text that passes 4.5:1 on every surface.
    static let secondaryText = dynamic(0x5E5D63, 0xB2B0B6)
    static let separator = dynamic(0xE2E1E6, 0x38363C)

    // MARK: Accent

    /// Marks and charts: 3:1 against cells in both modes.
    static let leafMid = dynamic(0x29945A, 0x3DB873)
    /// Text, links and glyphs use the asset accent.
    static let leaf = Color.accentColor
    /// Every filled control: white text at 5.4:1 in both modes.
    static let solid = Color(red: 0.106, green: 0.478, blue: 0.278)
    static let leafDeep = Color(red: 0.12, green: 0.54, blue: 0.36)
    static let leafLight = Color(red: 0.55, green: 0.85, blue: 0.62)
    static let blush = Color(red: 0.95, green: 0.48, blue: 0.66)

    // MARK: Shape

    /// One radius for every content card, concentric with the system's.
    static let cardRadius: CGFloat = 22
    static let heroRadius: CGFloat = 22
    static let mediaRadius: CGFloat = 18

    /// Kept for the share card, which is an image and not app chrome.
    static let hero = LinearGradient(
        colors: [Color(red: 0.15, green: 0.52, blue: 0.34), Color(red: 0.09, green: 0.39, blue: 0.29)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    /// Chart marks: one flat colour, no gradients.
    static func fill(_ base: Color = Theme.leafMid) -> Color { base }
    static func bar(_ base: Color = Theme.leafMid) -> Color { base }
    static func area(_ base: Color = Theme.leafMid) -> Color { base.opacity(0.14) }
    static func ring(_ base: Color = Theme.leafMid) -> Color { base }
}

/// The page behind scrolling content: plain and calm, no glow.
struct GlowBackground: View {
    var hue: Color = Theme.leafMid

    var body: some View {
        Theme.page.ignoresSafeArea()
    }
}

/// Content cards: opaque cells on the page. With Increase Contrast they
/// get a hairline edge, as Saiko Next does.
struct GlassCard: ViewModifier {
    var tint: Color?
    var padding: CGFloat = 16
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                let shape = RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                shape.fill(Theme.cell)
                    .overlay {
                        if contrast == .increased { shape.strokeBorder(Theme.secondaryText, lineWidth: 1) }
                    }
            }
    }
}

extension View {
    func glassCard(tint: Color? = nil, padding: CGFloat = 16) -> some View {
        modifier(GlassCard(tint: tint, padding: padding))
    }

    /// Fades and lifts content in when it first appears.
    func appearLift(delay: Double = 0) -> some View {
        modifier(AppearLift(delay: delay))
    }
}

private struct AppearLift: ViewModifier {
    let delay: Double
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 14)
            .onAppear {
                withAnimation(.spring(duration: 0.5, bounce: 0.25).delay(delay)) { shown = true }
            }
    }
}

/// A symbol on a washed tile, as in Saiko's settings and release notes.
struct TintedIconTile: View {
    let systemImage: String
    var hue: Color = .accentColor
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(hue)
            .frame(width: size, height: size)
            .background(hue.opacity(0.15), in: .rect(cornerRadius: size * 0.3))
            .accessibilityHidden(true)
    }
}

/// Taima's mascot, gently bobbing unless Reduce Motion is on.
struct Mascot: View {
    var size: CGFloat = 120
    var animated = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image("Mascot")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .phaseAnimator(animated && !reduceMotion ? [false, true] : [false]) { content, up in
                content
                    .offset(y: up ? -6 : 0)
                    .rotationEffect(.degrees(up ? 3 : -2))
            } animation: { _ in .easeInOut(duration: 1.6) }
            .accessibilityHidden(true)
    }
}

/// A short confirmation after saving.
struct SavedToast: View {
    let name: String

    var body: some View {
        Label("Saved \(name)", systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.semibold))
            .symbolEffect(.bounce, value: name)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(.regular.tint(Theme.leafMid.opacity(0.2)), in: .capsule)
            .accessibilityAddTraits(.isStaticText)
    }
}

/// A change that can be taken back for a few seconds.
struct UndoToast: View {
    let message: String
    let undo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(message)
                .font(.subheadline.weight(.semibold))
            Button("Undo", action: undo)
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
                .contentShape(.rect)
        }
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .glassEffect(.regular.tint(Theme.leafMid.opacity(0.2)), in: .capsule)
        .accessibilityElement(children: .contain)
        .onAppear { AccessibilityNotification.Announcement(String(localized: "\(message). Undo available.")).post() }
    }
}

/// A selected chip: tinted fill, coloured outline and primary text, so it
/// reads at any hue instead of relying on white on a light colour.
struct SelectableChipBackground: View {
    let isOn: Bool
    let hue: Color
    var shape: AnyShape = AnyShape(Capsule())

    var body: some View {
        ZStack {
            shape.fill(isOn ? AnyShapeStyle(hue.opacity(0.2)) : AnyShapeStyle(.fill.tertiary))
            if isOn { shape.stroke(hue, lineWidth: 1.5) }
        }
    }
}

/// Settings, reachable from every tab's toolbar.
struct SettingsToolbarButton: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button("Settings", systemImage: "gearshape") { model.showingSettings = true }
    }
}
