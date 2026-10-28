import ActivityKit
import AppIntents
import SwiftUI
import TaimaCore
import WidgetKit

@main
struct TaimaWidgetBundle: WidgetBundle {
    var body: some Widget {
        StashWidget()
        CurrentBagWidget()
        BagLiveActivity()
        EdibleTimerActivity()
        ScanControl()
    }
}

// MARK: - Timeline

struct SnapshotEntry: TimelineEntry {
    var date: Date
    var snapshot: WidgetSnapshot
    var thumbnail: UIImage?
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        // The app reloads timelines when anything changes; the hourly refresh
        // only keeps relative dates fresh.
        completion(Timeline(entries: [current()], policy: .after(.now.addingTimeInterval(3600))))
    }

    private func current() -> SnapshotEntry {
        var snapshot = SharedContainer.readSnapshot() ?? WidgetSnapshot(bags: [], hasThumbnail: false)
        let discreet = SharedContainer.isDiscreet
        if discreet {
            // Discreet mode: totals only, no names or photos.
            snapshot.latest?.name = "Latest item"
            snapshot.latest?.hasThumbnail = false
            snapshot.latest?.thc = nil
            snapshot.latest?.producer = nil
            snapshot.current?.name = "Bag in use"
            snapshot.current?.thc = nil
        }
        let thumbnail = snapshot.latest?.hasThumbnail == true
            ? SharedContainer.thumbnailURL.flatMap { UIImage(contentsOfFile: $0.path) } : nil
        return SnapshotEntry(date: .now, snapshot: snapshot, thumbnail: thumbnail)
    }
}

extension Color {
    static let leafLight = Color(red: 0.55, green: 0.85, blue: 0.62)
    static let leafMid = Color(red: 0.30, green: 0.76, blue: 0.50)
    static let leafDeep = Color(red: 0.12, green: 0.54, blue: 0.36)
}

/// Symbols and text stay solid; only the bars fade within their hue.
private let leafGradient = Color.leafMid
private let barFill = LinearGradient(colors: [.leafMid, .leafMid.opacity(0.7)], startPoint: .top, endPoint: .bottom)
private let pageFill = LinearGradient(colors: [Color(red: 0.07, green: 0.18, blue: 0.13), Color(red: 0.04, green: 0.12, blue: 0.09)], startPoint: .top, endPoint: .bottom)

private func grams(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0...1))) + " g"
}

// MARK: - Stash widget

struct StashWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "stash", provider: SnapshotProvider()) { entry in
            StashWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    pageFill
                }
                .widgetURL(URL(string: "taima://stash"))
        }
        .configurationDisplayName("Stash")
        .description("What's left, how long it lasts and what you collected last.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

struct StashWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        let snapshot = entry.snapshot
        switch family {
        case .accessoryInline:
            Label("\(grams(snapshot.stashGrams)) " + (snapshot.discreet ? "left" : "in stash"), systemImage: snapshot.symbol)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Label(snapshot.discreet ? "Left" : "Stash", systemImage: snapshot.symbol).font(.caption2.weight(.semibold))
                Text(grams(snapshot.stashGrams)).font(.title3.weight(.bold)).widgetAccentable()
                if let days = snapshot.daysOfSupply {
                    Text("≈ \(Int(days.rounded())) days at your pace").font(.caption2)
                }
            }
        case .systemMedium:
            HStack(spacing: 14) {
                stash(snapshot)
                Divider().overlay(.white.opacity(0.15))
                latest(snapshot)
            }
            .foregroundStyle(.white)
        default:
            stash(snapshot).foregroundStyle(.white)
        }
    }

    private func stash(_ snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(snapshot.discreet ? "Left" : "Stash", systemImage: snapshot.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(leafGradient)
            Text(grams(snapshot.stashGrams))
                .font(.system(.title, design: .rounded, weight: .bold))
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            if let limit = snapshot.weeklyLimit {
                Text("\(grams(snapshot.usedThisWeek)) of \(grams(limit)) this week")
                    .font(.caption)
                    .foregroundStyle(snapshot.usedThisWeek >= limit ? .orange : .white.opacity(0.7))
            } else {
                Text(snapshot.daysOfSupply.map { "≈ \(Int($0.rounded())) days left" } ?? "\(snapshot.fullCount) unopened")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer(minLength: 4)
            HStack(alignment: .bottom, spacing: 3) {
                let peak = max(snapshot.recentMonths.max() ?? 1, 1)
                ForEach(Array(snapshot.recentMonths.enumerated()), id: \.offset) { _, count in
                    Capsule()
                        .fill(barFill)
                        .frame(height: max(4, CGFloat(count) / CGFloat(peak) * 26))
                }
            }
            .frame(height: 26)
            .accessibilityLabel("Collected in the last six months")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func latest(_ snapshot: WidgetSnapshot) -> some View {
        if let latest = snapshot.latest {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.08))
                    if let thumbnail = entry.thumbnail {
                        Image(uiImage: thumbnail).resizable().scaledToFill()
                    } else {
                        Image(systemName: snapshot.symbol).foregroundStyle(leafGradient)
                    }
                }
                .frame(height: 64)
                .clipShape(.rect(cornerRadius: 12))
                Text(latest.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text([latest.thc.map { "THC \($0)" }, latest.grams.map(grams)].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetURL(URL(string: "taima://bag/\(latest.id.uuidString)"))
        } else {
            Text("Scan your first bag").font(.caption).foregroundStyle(.white.opacity(0.7))
        }
    }
}

// MARK: - Current bag widget

struct CurrentBagWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "current", provider: SnapshotProvider()) { entry in
            CurrentBagView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) {
                    pageFill
                }
        }
        .configurationDisplayName("Bag in use")
        .description("How much is left in the bag you are using, with buttons to log from the Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
    }
}

struct CurrentBagView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: WidgetSnapshot

    var body: some View {
        if let current = snapshot.current {
            let fraction = current.total.map { $0 > 0 ? min(1, current.remaining / $0) : 0 } ?? 1
            if family == .accessoryCircular {
                Gauge(value: fraction) {
                    Image(systemName: snapshot.symbol)
                } currentValueLabel: {
                    Text(current.remaining.formatted(.number.precision(.fractionLength(0...1))))
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .widgetURL(URL(string: "taima://bag/\(current.id.uuidString)"))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("In use").font(.caption.weight(.semibold)).foregroundStyle(leafGradient)
                        Spacer()
                        if let thc = current.thc { Text(thc).font(.caption2.weight(.semibold)).foregroundStyle(.white.opacity(0.7)) }
                    }
                    Text(current.name).font(.headline).lineLimit(2).foregroundStyle(.white)
                    Spacer(minLength: 0)
                    Text(grams(current.remaining) + " left")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    ProgressView(value: fraction).tint(.leafMid)
                    logButtons(current)
                }
                .widgetURL(URL(string: "taima://bag/\(current.id.uuidString)"))
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: snapshot.discreet ? "circle.hexagongrid" : "leaf").font(.title2).foregroundStyle(leafGradient)
                Text("Open a bag in Taima to track it here.")
                    .font(.caption).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.75))
            }
            .widgetURL(URL(string: "taima://stash"))
        }
    }
}

extension CurrentBagView {
    /// Small: one button. Medium: the amounts and a repeat of the last session.
    @ViewBuilder func logButtons(_ current: WidgetSnapshot.Current) -> some View {
        let id = current.id.uuidString
        let green = Color(red: 0.106, green: 0.478, blue: 0.278)
        if let unit = current.unitGrams {
            Button(intent: LogUseIntent(bagID: id, grams: unit)) {
                Label("One", systemImage: "minus").font(.caption.weight(.semibold)).frame(maxWidth: .infinity)
            }
            .tint(green)
            .accessibilityLabel("Log one preroll")
        } else if family == .systemMedium {
            HStack(spacing: 6) {
                ForEach(QuickAmounts.grams, id: \.self) { amount in
                    Button(intent: LogUseIntent(bagID: id, grams: amount)) {
                        Text("− " + QuickAmounts.label(amount)).font(.caption.weight(.semibold)).frame(maxWidth: .infinity)
                    }
                    .tint(green)
                }
                if current.lastGrams != nil {
                    Button(intent: RepeatLastIntent(bagID: id)) {
                        Image(systemName: "arrow.clockwise").font(.caption.weight(.bold)).frame(maxWidth: .infinity)
                    }
                    .tint(green)
                    .accessibilityLabel("Repeat last session")
                }
            }
        } else if let last = current.lastGrams {
            Button(intent: RepeatLastIntent(bagID: id)) {
                Label(QuickAmounts.label(last), systemImage: "arrow.clockwise").font(.caption.weight(.semibold)).frame(maxWidth: .infinity)
            }
            .tint(green)
            .accessibilityLabel("Repeat last session, \(QuickAmounts.label(last))")
        } else {
            Button(intent: LogUseIntent(bagID: id, grams: 0.25)) {
                Label(QuickAmounts.label(0.25), systemImage: "minus").font(.caption.weight(.semibold)).frame(maxWidth: .infinity)
            }
            .tint(green)
        }
    }
}

// MARK: - Live Activity

struct BagLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BagActivityAttributes.self) { context in
            LockScreenActivityView(context: context)
                .activityBackgroundTint(Color(red: 0.04, green: 0.12, blue: 0.08))
                .activitySystemActionForegroundColor(.leafMid)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    LimitedWidthReader { limited in
                        // A narrow island (landscape on iOS 27) keeps the icon only.
                        if limited {
                            Image(systemName: context.attributes.symbol).foregroundStyle(leafGradient)
                        } else {
                            Label(context.attributes.name, systemImage: context.attributes.symbol)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(leafGradient)
                                .lineLimit(1)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(leftLabel(context))
                        .font(.caption.weight(.bold))
                        .contentTransition(.numericText(value: context.state.remaining))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    LimitedWidthReader { limited in
                        VStack(spacing: 8) {
                            RemainingBar(context: context)
                            LogButtons(attributes: context.attributes, compact: limited)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: context.attributes.symbol).foregroundStyle(leafGradient)
            } compactTrailing: {
                Text(context.state.remaining.formatted(.number.precision(.fractionLength(0...1))) + "g")
                    .font(.caption2.weight(.bold))
                    .contentTransition(.numericText(value: context.state.remaining))
            } minimal: {
                Image(systemName: context.attributes.symbol).foregroundStyle(leafGradient)
            }
            .widgetURL(URL(string: "taima://bag/\(context.attributes.bagID)"))
            .keylineTint(.leafMid)
        }
    }
}

struct LockScreenActivityView: View {
    let context: ActivityViewContext<BagActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.name).font(.headline).foregroundStyle(.white).lineLimit(1)
                    Text((context.attributes.discreet ? "Today: " : "Used today: ") + grams(context.state.usedToday))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Text(leftLabel(context))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(leafGradient)
                    .contentTransition(.numericText(value: context.state.remaining))
            }
            RemainingBar(context: context)
            LogButtons(attributes: context.attributes)
        }
        .padding(16)
    }
}

struct RemainingBar: View {
    let context: ActivityViewContext<BagActivityAttributes>

    var body: some View {
        let fraction = context.attributes.total.map { $0 > 0 ? min(1, context.state.remaining / $0) : 0 } ?? 1
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.12))
                Capsule().fill(barFill).frame(width: max(8, proxy.size.width * fraction))
            }
        }
        .frame(height: 8)
        .accessibilityLabel("\(Int(fraction * 100)) percent left")
    }
}

private func leftLabel(_ context: ActivityViewContext<BagActivityAttributes>) -> String {
    if let left = context.attributes.unitsLeft(context.state.remaining) {
        return "\(left) left"
    }
    return grams(context.state.remaining) + " left"
}

/// Whether the Dynamic Island is narrow, as in landscape on iOS 27.
struct LimitedWidthReader<Content: View>: View {
    @ViewBuilder let content: (Bool) -> Content

    var body: some View {
        if #available(iOS 27.0, *) {
            LimitedWidthEnvironment(content: content)
        } else {
            content(false)
        }
    }
}

@available(iOS 27.0, *)
private struct LimitedWidthEnvironment<Content: View>: View {
    @Environment(\.isDynamicIslandLimitedInWidth) private var limited
    let content: (Bool) -> Content

    var body: some View { content(limited) }
}

struct LogButtons: View {
    let attributes: BagActivityAttributes
    /// One button only, for a narrow Dynamic Island.
    var compact = false

    var body: some View {
        HStack(spacing: 8) {
            amounts
            if !compact {
            Link(destination: URL(string: "taima://note/\(attributes.bagID)")!) {
                Image(systemName: "note.text.badge.plus")
                    .font(.caption.weight(.semibold))
                    .frame(width: 36, height: 30)
                    .background(.white.opacity(0.15), in: .capsule)
            }
            .accessibilityLabel("Add a note")
            }
        }
    }

    @ViewBuilder private var amounts: some View {
        if let unit = attributes.unitGrams {
            Button(intent: LogUseIntent(bagID: attributes.bagID, grams: unit)) {
                Label(attributes.discreet ? "Log one" : "Smoked one", systemImage: attributes.discreet ? "minus" : "smoke.fill")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.106, green: 0.478, blue: 0.278))
        } else {
            grams
        }
    }

    private var grams: some View {
        HStack(spacing: 8) {
            ForEach(compact ? [0.25] : QuickAmounts.grams, id: \.self) { amount in
                Button(intent: LogUseIntent(bagID: attributes.bagID, grams: amount)) {
                    Text("− " + QuickAmounts.label(amount))
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.106, green: 0.478, blue: 0.278))
            }
        }
    }
}

// MARK: - Control

struct ScanControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "scan") {
            ControlWidgetButton(action: OpenURLIntent(URL(string: "taima://scan")!)) {
                Label("Scan a bag", systemImage: "camera.viewfinder")
            }
        }
        .displayName("Scan a bag")
        .description("Opens Taima's camera to read a bag label.")
    }
}

// MARK: - Edible timer

struct EdibleTimerActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: EdibleTimerAttributes.self) { context in
            EdibleTimerView(context: context)
                .activityBackgroundTint(Color(red: 0.04, green: 0.12, blue: 0.08))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.discreet ? "Timer" : "Edible", systemImage: "timer")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(leafGradient)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.state.takenAt...Date.distantFuture, countsDown: false)
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .frame(maxWidth: 64)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(EdibleTimerView.advice(context))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            } compactLeading: {
                Image(systemName: "timer").foregroundStyle(leafGradient)
            } compactTrailing: {
                Text(timerInterval: context.state.takenAt...Date.distantFuture, countsDown: false)
                    .monospacedDigit()
                    .font(.caption2.weight(.bold))
                    .frame(maxWidth: 44)
            } minimal: {
                Image(systemName: "timer").foregroundStyle(leafGradient)
            }
        }
    }
}

struct EdibleTimerView: View {
    let context: ActivityViewContext<EdibleTimerAttributes>

    /// Fixed wording: the activity isn't updated while it runs.
    static func advice(_ context: ActivityViewContext<EdibleTimerAttributes>) -> String {
        context.isStale
            ? "Over 90 minutes since you took it."
            : "Effects can take 30 to 90 minutes to start. Wait at least 90 minutes before taking more."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label(context.attributes.discreet ? "Timer" : "Edible taken", systemImage: "timer")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(timerInterval: context.state.takenAt...Date.distantFuture, countsDown: false)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(leafGradient)
                    .multilineTextAlignment(.trailing)
            }
            ProgressView(timerInterval: context.state.takenAt...context.state.takenAt.addingTimeInterval(EdibleTimer.latest), countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(.leafMid)
            Text(Self.advice(context))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(16)
    }
}
