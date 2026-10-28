import SwiftUI
import TaimaCore

struct ToolsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        CountdownCard(now: context.date)
                    }
                    .appearLift()
                    // Tops line up; one column once text is very large.
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top),
                                             count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                        tool(String(localized: "Joints & doses"), String(localized: "How far your stash goes"), "flame", Theme.leafMid) { JointCalculator() }
                        tool(String(localized: "Edibles"), String(localized: "THC per portion"), "birthday.cake", Theme.leafDeep) { EdibleCalculator() }
                        tool(String(localized: "Tolerance break"), String(localized: "Count the days"), "pause.circle", Theme.leafDeep) { BreakTracker() }
                        tool(String(localized: "Party games"), String(localized: "Cards for the whole circle"), "suit.club.fill", Theme.leafMid) { RouletteView() }
                        tool(String(localized: "Decarb guide"), String(localized: "Oven times and temperatures"), "thermometer.medium", Theme.leafMid) { DecarbGuide() }
                        tool(String(localized: "Stash age"), String(localized: "How long bags have waited"), "clock.arrow.circlepath", Theme.leafDeep) { StashAge() }
                        tool(String(localized: "Safer use"), String(localized: "Tips and where to get help"), "heart.text.square", Theme.leafMid) { SaferUseView() }
                        tool(String(localized: "Self-check"), String(localized: "Eight private questions"), "checklist", Theme.leafDeep) { SelfCheckView() }
                    }
                    .appearLift(delay: 0.05)
                }
                .padding()
            }
            .background(GlowBackground())
            .navigationTitle("Tools")
            .navigationDestination(for: UUID.self) { BagDetailView(id: $0) }
            .navigationDestination(for: StrainInfo.self) { StrainInfoView(strain: $0) }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { SettingsToolbarButton() } }
        }
    }

    private func tool<Destination: View>(_ title: String, _ detail: String, _ symbol: String, _ hue: Color, @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink {
            destination()
                .background(GlowBackground(hue: hue))
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                TintedIconTile(systemImage: symbol, hue: hue, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundStyle(.primary)
                    Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            .glassCard(padding: 14)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 4:20

private struct CountdownCard: View {
    let now: Date

    var body: some View {
        let next = StashMath.next420(after: now)
        let seconds = Int(next.timeIntervalSince(now))
        let isNow = Calendar.current.component(.minute, from: now) == 20 && [4, 16].contains(Calendar.current.component(.hour, from: now))
        let days = StashMath.daysUntil420Day(from: now)
        // Two figures side by side on a plain cell; the time is the hero.
        HStack(alignment: .top, spacing: 0) {
            figure(isNow ? String(localized: "It's 4:20") : String(localized: "Next 4:20"),
                   isNow ? String(localized: "🌿 Enjoy") : String(format: "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60),
                   value: Double(seconds))
                .animation(.snappy, value: seconds)
            Divider().overlay(Theme.separator).padding(.horizontal, 14)
            figure(days == 0 ? String(localized: "Today is 4/20") : String(localized: "Next 4/20"),
                   days == 0 ? String(localized: "Happy 4/20 🌿") : String(localized: "\(days) days"),
                   value: Double(days))
        }
        .fixedSize(horizontal: false, vertical: true)
        .glassCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken(seconds: seconds, isNow: isNow, days: days))
    }

    private func figure(_ label: String, _ value: String, value number: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.subheadline).foregroundStyle(Theme.secondaryText)
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Theme.leaf)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText(value: number))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Rounded to the minute, so VoiceOver isn't reading a changing clock.
    private func spoken(seconds: Int, isNow: Bool, days: Int) -> String {
        let time = isNow ? String(localized: "It's 4:20.") : String(localized: "Next 4:20 in \(Duration.seconds((seconds / 60 + 1) * 60).formatted(.units(allowed: [.hours, .minutes], width: .wide))).")
        let day = days == 0 ? String(localized: "Today is 4/20.") : String(localized: "Next 4/20 in \(days) days.")
        return time + " " + day
    }
}

// MARK: - Bag picking

/// Chooses a bag's THC for a calculation, defaulting to the bag in use.
private struct THCSource: View {
    @Environment(AppModel.self) private var model
    @Binding var thc: Double

    var body: some View {
        let bags = model.bags.filter { $0.thc != nil }
        Menu {
            ForEach(bags.prefix(30)) { bag in
                Button("\(bag.displayName) · \(bag.thc!.label)") { thc = bag.thc!.percent }
            }
        } label: {
            Label("From a bag", systemImage: "bag")
        }
        .disabled(bags.isEmpty)
        .onAppear {
            if let current = model.currentBag?.thc?.percent { thc = current }
        }
    }
}

private struct Result: View {
    let value: String
    let label: String
    var hue: Color = Theme.leafMid

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(hue)
                .contentTransition(.numericText())
                .animation(.snappy, value: value)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Joints

private struct JointCalculator: View {
    @Environment(AppModel.self) private var model
    @AppStorage("tools.perJoint") private var perJoint = 0.3
    @State private var thc = 20.0

    var body: some View {
        // Only loose flower is rolled: prerolls are joints already, and hash is
        // its own thing.
        let inStash = model.bags.filter { $0.stock != .empty }
        let loose = inStash.filter { $0.form == .bag || $0.form == .jar }.map(\.remaining).reduce(0, +)
        let prerolls = inStash.compactMap(\.unitsLeft).reduce(0, +)
        let current = model.currentBag
        Form {
            Section {
                HStack(spacing: 12) {
                    let joints = StashMath.joints(grams: loose, perJoint: perJoint)
                    Result(value: "\(joints)", label: joints == 1 ? String(localized: "joint from your loose flower") : String(localized: "joints from your loose flower"))
                    if let current, let left = current.unitsLeft {
                        Result(value: "\(left)", label: left == 1 ? String(localized: "preroll left in use") : String(localized: "prerolls left in use"), hue: Theme.leafDeep)
                    } else if let current, current.form != .hash {
                        Result(value: "\(StashMath.joints(grams: current.remaining, perJoint: perJoint))", label: String(localized: "from the one in use"), hue: Theme.leafDeep)
                    }
                }
                if prerolls > 0 {
                    Text("Plus \(String(localized: "\(prerolls) prerolls")) ready to smoke.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Result(value: String(localized: "\(Int(StashMath.thcMilligrams(grams: perJoint, thcPercent: thc).rounded())) mg"), label: String(localized: "THC in one joint's flower, before burning losses"), hue: .orange)
            }
            Section("Per joint") {
                Stepper(value: $perJoint, in: 0.1...1.5, step: 0.05) {
                    Text(perJoint.formatted(.number.precision(.fractionLength(2))) + " g")
                        .monospacedDigit()
                }
            }
            Section {
                Stepper(value: $thc, in: 1...35, step: 0.5) {
                    Text("THC \(thc.formatted(.number.precision(.fractionLength(0...1))))%")
                        .monospacedDigit()
                }
                THCSource(thc: $thc)
            } header: {
                Text("Strength")
            } footer: {
                Text("Smoking delivers only part of this THC, often a third or less.")
            }
        }
        .scrollContentBackground(.hidden)
        .sensoryFeedback(.selection, trigger: perJoint)
    }
}

// MARK: - Edibles

private struct EdibleCalculator: View {
    @State private var grams = 1.0
    @State private var thc = 20.0
    @State private var efficiency = 0.6
    @State private var portions = 10
    @State private var timerStarted = false

    var body: some View {
        let estimate = StashMath.edible(grams: grams, thcPercent: thc, efficiency: efficiency, portions: portions)
        Form {
            Section {
                HStack(spacing: 12) {
                    Result(value: String(localized: "\(Int(estimate.perPortionMilligrams.rounded())) mg"), label: String(localized: "per portion"), hue: .pink)
                    Result(value: String(localized: "\(Int(estimate.totalMilligrams.rounded())) mg"), label: String(localized: "in the whole batch"))
                }
            } footer: {
                Text("An estimate. Edibles take 30 minutes to 2 hours to work; many people start with 2.5 to 5 mg and wait before taking more.")
            }
            Section {
                Button("I took a portion: start a wait timer", systemImage: "timer") {
                    EdibleTimer.start(milligrams: estimate.perPortionMilligrams)
                    timerStarted = true
                }
                .disabled(timerStarted)
            } footer: {
                Text(timerStarted ? String(localized: "The timer is on your Lock Screen.") : String(localized: "Counts the time since you took it, so you wait before taking more."))
            }
            Section("Flower") {
                Stepper(value: $grams, in: 0.25...28, step: 0.25) {
                    Text(grams.formatted(.number.precision(.fractionLength(0...2))) + " g").monospacedDigit()
                        .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
                }
                Stepper(value: $thc, in: 1...35, step: 0.5) {
                    Text("THC \(thc.formatted(.number.precision(.fractionLength(0...1))))%").monospacedDigit()
                }
                THCSource(thc: $thc)
            }
            Section {
                VStack(alignment: .leading) {
                    Text("Decarb and infusion yield \(Int(efficiency * 100))%")
                    Slider(value: $efficiency, in: 0.3...0.9, step: 0.05).tint(.pink)
                }
                Stepper("\(portions) portions", value: $portions, in: 1...100)
            } header: {
                Text("Batch")
            } footer: {
                Text("Home infusions typically keep about half to three quarters of the label THC.")
            }
        }
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Tolerance break

private struct BreakTracker: View {
    @Environment(AppModel.self) private var model
    @State private var start: Date? = SharedContainer.defaults?.object(forKey: SharedContainer.breakStartKey) as? Date
    @State private var confirmingEnd = false
    @State private var history = BreakHistory.load()
    /// The pace before the break, so savings don't shrink as the break goes on.
    @AppStorage("tbreak.pace") private var pace = 0.0
    @AppStorage("tbreak.pricePerGram") private var pricePerGram = 0.0

    private let milestones: [(Int, String)] = [
        (2, String(localized: "Two days: sleep and appetite often start to settle.")),
        (7, String(localized: "One week in.")),
        (14, String(localized: "Two weeks: a common length for a short break.")),
        (28, String(localized: "Four weeks: studies of daily users saw cannabinoid receptors largely back to normal around here."))
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let start {
                    let days = StashMath.breakDays(since: start)
                    ZStack {
                        Circle().stroke(.quaternary, lineWidth: 14)
                        Circle()
                            .trim(from: 0, to: min(1, Double(days) / 28))
                            .stroke(Theme.ring(.teal), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 0) {
                            Text("\(days)")
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                .contentTransition(.numericText())
                            Text(String(localized: "break.days.unit", defaultValue: "\(days) days", comment: "Unit below the large day count; omit the number in both plural variants.")).foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 220, height: 220)
                    .padding(.top)
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(milestones, id: \.0) { day, text in
                            Label {
                                Text(text).font(.subheadline)
                            } icon: {
                                Image(systemName: days >= day ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(days >= day ? AnyShapeStyle(Theme.leaf) : AnyShapeStyle(.tertiary))
                                    .symbolEffect(.bounce, value: days >= day)
                            }
                        }
                    }
                    .glassCard()
                    if pace > 0 {
                        let record = BreakRecord(start: start)
                        let saved = record.savings(dailyGrams: pace, pricePerGram: pricePerGram > 0 ? pricePerGram : nil)
                        HStack(spacing: 12) {
                            savingTile(saved.grams.gramsLabel, String(localized: "not used"))
                            if let euros = saved.euros {
                                savingTile(euros.formatted(.currency(code: "EUR").precision(.fractionLength(0))), String(localized: "kept"))
                            }
                        }
                    }
                    Button("End break", role: .destructive) { confirmingEnd = true }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                } else {
                    Image(systemName: "pause.circle")
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(Theme.leaf)
                        .padding(.top, 30)
                        .accessibilityHidden(true)
                    Text("Take a break").font(.title2.bold())
                    Text("Start a tolerance break and Taima counts the days. Nothing is logged against your stash.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Button("Start today", systemImage: "play.fill") { set(.now) }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.solid)
                        .controlSize(.large)
                }
            if !history.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Past breaks").font(.headline)
                    ForEach(history.prefix(8)) { record in
                        HStack {
                            Text(record.start.formatted(date: .abbreviated, time: .omitted))
                            Spacer()
                            Text("\(record.days()) days").fontWeight(.semibold).monospacedDigit()
                        }
                        .font(.subheadline)
                    }
                }
                .glassCard()
            }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .confirmationDialog("End your break?", isPresented: $confirmingEnd, titleVisibility: .visible) {
            Button("End break", role: .destructive) { set(nil) }
        }
        .sensoryFeedback(.success, trigger: start)
        .animation(.spring, value: start)
    }

    private func savingTile(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.weight(.bold)).fontDesign(.rounded)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .glassCard(padding: 12)
    }

    private func set(_ date: Date?) {
        if date == nil, let start {
            history.insert(BreakRecord(start: start, end: .now), at: 0)
            BreakHistory.save(history)
        } else if date != nil {
            pace = model.inventory.dailyAverage
            pricePerGram = CollectionStats(bags: model.bags).averagePricePerGram ?? 0
        }
        start = date
        SharedContainer.defaults?.set(date, forKey: SharedContainer.breakStartKey)
    }
}

enum BreakHistory {
    static let key = "tbreak.history"

    static func load() -> [BreakRecord] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([BreakRecord].self, from: data)) ?? []
    }

    static func save(_ records: [BreakRecord]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(records), forKey: key)
    }
}


// MARK: - Decarb

private struct DecarbGuide: View {
    var body: some View {
        List {
            Section {
                row(String(localized: "Oven"), String(localized: "110–120 °C for 30–45 minutes"), "oven")
                row(String(localized: "Sous vide"), String(localized: "95 °C for 90 minutes, sealed"), "drop.circle")
                row(String(localized: "Butter or oil"), String(localized: "Below 90 °C for 2–3 hours after decarbing"), "flame")
            } header: {
                Text("Common home methods")
            } footer: {
                Text("Decarboxylation turns THCA into THC. Spread ground flower thinly on baking paper and keep the oven below 125 °C to protect terpenes. Oven thermostats vary, so an oven thermometer helps.")
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func row(_ title: String, _ detail: String, _ symbol: String) -> some View {
        HStack(spacing: 12) {
            TintedIconTile(systemImage: symbol, hue: Theme.leafMid, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Stash age

private struct StashAge: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let bags = model.bags.filter { $0.stock != .empty && $0.packedOn != nil }
            .sorted { $0.packedOn! < $1.packedOn! }
        List {
            if bags.isEmpty {
                Text("Full and open bags with a packing date show up here, oldest first.")
                    .foregroundStyle(.secondary)
            }
            ForEach(bags) { bag in
                let days = Calendar.taima.dateComponents([.day], from: bag.packedOn!, to: .now).day ?? 0
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bag.displayName).font(.headline)
                        Text("Packed \(bag.packedOn!.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(days) days")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(days > 180 ? .orange : Theme.leafDeep)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}
