import SwiftUI

/// Taima's surfaces: a softly lit page, glass cards and the leaf gradient,
/// after Saiko's tinted-glass look.
enum Theme {
    static let leafLight = Color(red: 0.55, green: 0.85, blue: 0.62)
    /// Slightly deeper in light mode so marks keep 3:1 against white cards.
    static let leafMid = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.24, green: 0.72, blue: 0.45, alpha: 1)
            : UIColor(red: 0.16, green: 0.58, blue: 0.35, alpha: 1)
    })
    /// One radius for every content card.
    static let cardRadius: CGFloat = 22
    /// Hero cards at the top of a tab.
    static let heroRadius: CGFloat = 28
    /// Photos inside content.
    static let mediaRadius: CGFloat = 18

    /// Fill behind white text: 5.4:1 in both modes.
    static let solid = Color(red: 0.106, green: 0.478, blue: 0.278)
    static let leafDeep = Color(red: 0.12, green: 0.54, blue: 0.36)
    static let blush = Color(red: 0.95, green: 0.48, blue: 0.66)

    /// Text and symbols use the plain accent; gradients are for surfaces only.
    static let leaf = Color.accentColor

    /// Hero surfaces: two neighbouring greens, barely apart.
    static let hero = LinearGradient(
        colors: [Color(red: 0.15, green: 0.52, blue: 0.34), Color(red: 0.09, green: 0.39, blue: 0.29)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    /// A mark that fades slightly within its own hue.
    static func fill(_ base: Color = .accentColor) -> LinearGradient {
        LinearGradient(colors: [base, base.opacity(0.72)], startPoint: .top, endPoint: .bottom)
    }

    static func bar(_ base: Color = .accentColor) -> LinearGradient { fill(base) }

    static func area(_ base: Color = .accentColor) -> LinearGradient {
        LinearGradient(colors: [base.opacity(0.22), base.opacity(0)], startPoint: .top, endPoint: .bottom)
    }

    static func ring(_ base: Color = Theme.leafMid) -> AngularGradient {
        AngularGradient(colors: [base.opacity(0.7), base], center: .center, startAngle: .degrees(0), endAngle: .degrees(360))
    }
}

/// The page behind scrolling content: two soft glows over the grouped background.
/// The page behind scrolling content: the grouped background with one faint
/// wash of the accent at the top.
struct GlowBackground: View {
    @Environment(\.colorScheme) private var scheme
    var hue: Color = Theme.leafMid

    var body: some View {
        Color(.systemGroupedBackground)
            .overlay(alignment: .top) {
                LinearGradient(colors: [hue.opacity(scheme == .dark ? 0.14 : 0.10), hue.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 340)
            }
            .ignoresSafeArea()
    }
}

/// Content cards, after Saiko: a light material in light mode and a solid
/// card in dark mode or with Reduce Transparency. Liquid Glass is kept for
/// controls, as the HIG asks.
struct GlassCard: ViewModifier {
    var tint: Color?
    var padding: CGFloat = 16
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                let shape = RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                ZStack {
                    if scheme == .dark || reduceTransparency {
                        shape.fill(Color(.secondarySystemGroupedBackground))
                    } else {
                        shape.fill(.regularMaterial)
                        // Light cards need an edge to stand off the page.
                        shape.fill(Theme.leafMid.opacity(0.035))
                        shape.strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5)
                    }
                    if let tint { shape.fill(tint.opacity(scheme == .dark ? 0.12 : 0.08)) }
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
