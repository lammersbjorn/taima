import Charts
import SwiftUI
import TaimaCore

/// Inventory: the bag in use, open and full bags, and what was used lately.
struct StashView: View {
    @Environment(AppModel.self) private var model
    @State private var deducting: Bag?
    @State private var editingSession: SessionRef?
    @State private var showingLimits = false
    @State private var logged = 0

    struct SessionRef: Identifiable {
        let bag: Bag
        let entry: UsageEntry
        var id: UUID { entry.id }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    let summary = model.inventory
                    UpdateNotices()
                    header(summary)
                        .appearLift()
                    if let current = model.currentBag {
                        CurrentBagCard(bag: current, onCustom: { deducting = current }, onQuick: { amount in
                            model.use(amount, from: current)
                            logged += 1
                        })
                        .appearLift(delay: 0.05)
                    } else if model.openBags.isEmpty && model.fullBags.isEmpty {
                        emptyState.appearLift(delay: 0.05)
                    } else {
                        pickCurrentHint.appearLift(delay: 0.05)
                    }
                    WeeklyCard(summary: summary) { showingLimits = true }
                        .appearLift(delay: 0.08)
                    if !summary.days.allSatisfy({ $0.grams == 0 }) {
                        usageChart(summary).appearLift(delay: 0.1)
                    }
                    bagSection(String(localized: "Open"), bags: model.openBags.filter { $0.id != model.currentBagID }, systemImage: "bag")
                    bagSection(String(localized: "Full bags"), bags: model.fullBags.useFirstOrder, systemImage: "bag.fill", markFirst: true)
                    recentUse
                }
                .padding()
                .animation(.spring(duration: 0.4), value: model.bags)
            }
            .background(GlowBackground())
            .navigationTitle("Stash")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { SettingsToolbarButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Scan a label", systemImage: "camera") { model.destination = .scan }
                        Button("Check a bag in the shop", systemImage: "barcode.viewfinder") { model.showingChecker = true }
                        Button("Choose photos", systemImage: "photo.on.rectangle") { model.destination = .pick }
                        Button("Add without photo", systemImage: "square.and.pencil") { model.startManualDraft() }
                    } label: {
                        Label("Add bag", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: StrainInfo.self) { StrainInfoView(strain: $0) }
            .navigationDestination(for: UUID.self) { BagDetailView(id: $0) }
            .sheet(item: $deducting) { bag in
                DeductSheet(bag: bag)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingLimits) {
                LimitsSheet().presentationDetents([.medium, .large])
            }
            .sheet(item: $editingSession) { ref in
                SessionEditSheet(bag: ref.bag, entry: ref.entry)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: logged)
        }
    }

    private func header(_ summary: InventorySummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("In your stash")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                    Text(summary.stashGrams.gramsLabel)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(value: summary.stashGrams))
                }
                Spacer()
                Mascot(size: model.currentBag == nil ? 70 : 52)
            }
            HStack(spacing: 10) {
                if summary.fullCount > 0 { pill(String(localized: "\(summary.fullCount) full"), "bag.fill") }
                if summary.openCount > 0 { pill(String(localized: "\(summary.openCount) open"), "bag") }
                if let days = summary.daysOfSupply {
                    pill(String(localized: "≈ \(Int(days.rounded())) days"), "hourglass")
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.hero, in: .rect(cornerRadius: Theme.heroRadius))
        .shadow(color: Theme.leafDeep.opacity(0.18), radius: 12, y: 6)
        .accessibilityElement(children: .combine)
    }

    private func pill(_ text: String, _ symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.white.opacity(0.18), in: .capsule)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bag.badge.plus").font(.largeTitle).foregroundStyle(Theme.leaf)
            Text("No bags in your stash").font(.headline)
            Text("When you add a bag, set it to Full. Open it here to track what you use; the Live Activity lets you log from the Lock Screen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    private var pickCurrentHint: some View {
        Label("Open a bag or pick one below to log what you use.", systemImage: "hand.tap")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .glassCard()
    }

    private func usageChart(_ summary: InventorySummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Last 30 days").font(.headline)
                Spacer()
                Text("\(summary.dailyAverage.formatted(.number.precision(.fractionLength(2)))) g a day")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Chart(summary.days) { day in
                AreaMark(x: .value(String(localized: "Day"), day.date, unit: .day), y: .value(String(localized: "Grams"), day.grams))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Theme.area(Theme.leafMid))
                LineMark(x: .value(String(localized: "Day"), day.date, unit: .day), y: .value(String(localized: "Grams"), day.grams))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Theme.leafMid)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            .chartYAxis { AxisMarks(values: .automatic(desiredCount: 3)) { AxisGridLine(); AxisValueLabel() } }
            .chartXAxis { AxisMarks(values: .stride(by: .day, count: 7)) { AxisValueLabel(format: .dateTime.day().month(.abbreviated)) } }
            .frame(height: 140)
        }
        .glassCard()
    }

    @ViewBuilder private func bagSection(_ title: String, bags: [Bag], systemImage: String, markFirst: Bool = false) -> some View {
        if !bags.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: systemImage).font(.headline)
                ForEach(bags) { bag in
                    HStack(spacing: 12) {
                        NavigationLink(value: bag.id) {
                            HStack(spacing: 12) {
                                BagPhoto(name: bag.mainPhoto)
                                    .frame(width: 48, height: 48)
                                    .clipShape(.rect(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(bag.displayName).font(.subheadline.weight(.semibold)).lineLimit(1)
                                        if markFirst, bags.count > 1, bag.id == bags.first?.id, bag.packedOn != nil {
                                            Chip(title: "", value: String(localized: "Use first"), prominent: true)
                                        }
                                    }
                                    Text(bag.stock == .open ? String(localized: "\(bag.remainingLabel) left") : bag.remainingLabel)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .contentTransition(.numericText())
                                }
                                Spacer(minLength: 0)
                            }
                        }
                        .buttonStyle(.plain)
                        Button(bag.stock == .full ? String(localized: "Open") : String(localized: "Use")) {
                            withAnimation(.spring) { model.open(bag) }
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.leafMid)
                        .controlSize(.large)
                    }
                    .contextMenu {
                        Button("Use this bag", systemImage: "leaf") { model.open(bag) }
                        Button("Log a session", systemImage: "square.and.pencil") { deducting = bag }
                        Button("Mark as empty", systemImage: "bag.badge.minus") { model.setStock(.empty, for: bag) }
                    }
                }
            }
            .glassCard()
        }
    }

    @ViewBuilder private var recentUse: some View {
        let entries = model.bags.flatMap { bag in bag.usage.map { (bag, $0) } }
            .sorted { $0.1.date > $1.1.date }
            .prefix(8)
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label("Recent use", systemImage: "clock").font(.headline)
                ForEach(Array(entries), id: \.1.id) { bag, entry in
                    HStack(spacing: 10) {
                        Image(systemName: entry.method?.symbol ?? "minus.circle")
                            .foregroundStyle(Theme.leafMid)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.grams.formatted(.number.precision(.fractionLength(0...2))) + " g · " + bag.displayName)
                                .font(.subheadline)
                                .lineLimit(1)
                            HStack(spacing: 4) {
                                Text(entry.date.formatted(.relative(presentation: .named)))
                                if let change = entry.moodChange {
                                    Text("· mood \(change > 0 ? "+" : "")\(change)")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            withAnimation { model.undoUse(entry, in: bag) }
                        } label: {
                            Label("Remove", systemImage: "arrow.uturn.backward")
                                .labelStyle(.iconOnly)
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Remove this use")
                    }
                    .contentShape(.rect)
                    .onTapGesture { editingSession = SessionRef(bag: bag, entry: entry) }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { editingSession = SessionRef(bag: bag, entry: entry) }
                    .accessibilityHint("Edit this session")
                }
            }
            .glassCard()
        }
    }
}

/// The bag in use: a remaining ring and quick amounts.
struct CurrentBagCard: View {
    @Environment(AppModel.self) private var model
    let bag: Bag
    let onCustom: () -> Void
    let onQuick: (Double) -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                RemainingRing(fraction: bag.fractionLeft ?? 1, remaining: bag.remaining)
                    .frame(width: 112, height: 112)
                VStack(alignment: .leading, spacing: 4) {
                    Label(bag.form == .bag ? String(localized: "In use") : String(localized: "In use · \(bag.form.label)"), systemImage: bag.form == .bag ? "leaf.fill" : bag.form.symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.leaf)
                    NavigationLink(value: bag.id) {
                        Text(bag.displayName)
                            .font(.title3.weight(.bold))
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(.primary)
                    }
                    Text([bag.thc.map { "THC \($0.label)" }, bag.grams.map { String(localized: "of \($0.gramsLabel)") }].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let left = bag.unitsLeft, let count = bag.unitCount {
                        Text("\(left) of \(count) prerolls left")
                            .font(.caption.weight(.semibold))
                            .contentTransition(.numericText())
                    }
                    if let last = bag.lastUse {
                        Text("Last use \(last.formatted(.relative(presentation: .named)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                if let unit = bag.gramsPerUnit {
                    Button {
                        withAnimation(.spring(duration: 0.45, bounce: 0.3)) { onQuick(unit) }
                    } label: {
                        Label("Smoked one", systemImage: "smoke.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.solid)
                    .controlSize(.large)
                } else {
                    ForEach(QuickAmounts.grams, id: \.self) { amount in
                        Button {
                            withAnimation(.spring(duration: 0.45, bounce: 0.3)) { onQuick(amount) }
                        } label: {
                            Text("− " + QuickAmounts.label(amount))
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.leafMid)
                        .controlSize(.large)
                    }
                }
            }
            // Amounts in one row; the fuller actions below, so nothing wraps.
            HStack(spacing: 8) {
                Button(action: onCustom) {
                    Label("Log a session", systemImage: "square.and.pencil")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                Button { model.noteTarget = bag } label: {
                    Label("Add a note", systemImage: "note.text.badge.plus")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .glassCard(tint: Theme.leafMid)
    }
}

struct RemainingRing: View {
    let fraction: Double
    let remaining: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().stroke(Theme.leafMid.opacity(0.15), lineWidth: 12)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Theme.ring(), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(remaining.formatted(.number.precision(.fractionLength(0...2))))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .contentTransition(.numericText(value: remaining))
                Text("grams left").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.6, bounce: 0.2), value: fraction)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(remaining.formatted()) grams left")
    }
}

/// Logs a session: how much, how, and how it felt. Only the amount is needed.
struct DeductSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let bag: Bag
    @State private var amount = 0.25
    @AppStorage("session.method") private var lastMethod = ""
    @State private var method: ConsumptionMethod?
    @State private var moodBefore: Int?
    @State private var moodAfter: Int?
    @State private var note = ""
    @State private var withTobacco: Bool?
    @State private var startTimer = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 14) {
                        Text(bag.gramsPerUnit != nil ? String(localized: "\(units) prerolls") : amount.formatted(.number.precision(.fractionLength(2))) + " g")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .contentTransition(.numericText(value: amount))
                            .foregroundStyle(Theme.leaf)
                            .frame(maxWidth: .infinity)
                        if let unit = bag.gramsPerUnit {
                            Stepper("Prerolls", value: Binding(get: { units }, set: { amount = Double($0) * unit }), in: 1...max(1, bag.unitsLeft ?? 1))
                                .labelsHidden()
                        } else {
                            Slider(value: $amount, in: 0.05...max(0.1, min(5, bag.remaining)), step: 0.05)
                                .tint(Theme.leafMid)
                            HStack {
                                ForEach([0.1, 0.2, 0.3, 0.5, 1.0], id: \.self) { value in
                                    Button(value.formatted()) { withAnimation(.snappy) { amount = min(value, bag.remaining) } }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                }
                            }
                        }
                        Text("\(max(0, bag.remaining - amount).formatted(.number.precision(.fractionLength(0...2)))) g will be left in \(bag.displayName).")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 6)
                }
                SessionDetailsSection(method: $method, moodBefore: $moodBefore, moodAfter: $moodAfter, note: $note, withTobacco: $withTobacco)
                if method == .edible {
                    Section {
                        Toggle("Start a wait timer", isOn: $startTimer)
                    } footer: {
                        Text("Shows on the Lock Screen how long ago you took it. Edibles take 30 to 90 minutes to work.")
                    }
                }
            }
            .navigationTitle("Log a session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", role: .cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log", systemImage: "checkmark") {
                        if let method { lastMethod = method.rawValue }
                        let details = UsageEntry(grams: amount, method: method, moodBefore: moodBefore, moodAfter: moodAfter,
                                                 note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note,
                                                 withTobacco: withTobacco)
                        model.use(amount, from: bag, details: details)
                        if method == .edible && startTimer { EdibleTimer.start(milligrams: nil) }
                        dismiss()
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(bag.remaining <= 0)
                }
            }
            .onAppear {
                method = ConsumptionMethod(rawValue: lastMethod)
                if let unit = bag.gramsPerUnit { amount = unit }
            }
            .sensoryFeedback(.selection, trigger: amount)
        }
    }

    private var units: Int {
        guard let unit = bag.gramsPerUnit, unit > 0 else { return 0 }
        return max(1, Int((amount / unit).rounded()))
    }
}

/// Method, mood before and after, and a note.
struct SessionDetailsSection: View {
    @Binding var method: ConsumptionMethod?
    @Binding var moodBefore: Int?
    @Binding var moodAfter: Int?
    @Binding var note: String
    @Binding var withTobacco: Bool?

    var body: some View {
        Section {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(ConsumptionMethod.allCases) { option in
                        let isOn = method == option
                        Button {
                            withAnimation(.snappy(duration: 0.2)) { method = isOn ? nil : option }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: option.symbol).font(.title3)
                                Text(option.label).font(.caption)
                            }
                            .frame(width: 64, height: 58)
                            .foregroundStyle(.primary)
                            .background { SelectableChipBackground(isOn: isOn, hue: Theme.leafMid, shape: AnyShape(RoundedRectangle(cornerRadius: 14))) }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                    }
                }
            }
            .scrollIndicators(.hidden)
            if method != .vape && method != .edible {
                Picker("Mixed with tobacco", selection: $withTobacco) {
                    Text("Not noted").tag(Bool?.none)
                    Text("No").tag(Bool?.some(false))
                    Text("Yes").tag(Bool?.some(true))
                }
            }
            MoodRow(title: String(localized: "Mood before"), mood: $moodBefore)
            MoodRow(title: String(localized: "Mood after"), mood: $moodAfter)
            TextField("Note: where, with whom, how it was", text: $note, axis: .vertical)
                .lineLimit(2...5)
        } header: {
            Text("Session")
        } footer: {
            Text("Optional. Moods let Stats show which strains and methods lift you most.")
        }
    }
}

struct MoodRow: View {
    let title: String
    @Binding var mood: Int?
    @Environment(\.dynamicTypeSize) private var typeSize

    static let symbols = ["cloud.rain.fill", "cloud.fill", "cloud.sun.fill", "sun.max.fill", "sparkles"]
    static let labels = [String(localized: "Low"), String(localized: "Meh"), String(localized: "Okay"), String(localized: "Good"), String(localized: "Great")]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline)
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 6)) : AnyLayout(HStackLayout(spacing: 6))
            layout {
                ForEach(1...5, id: \.self) { value in
                    let isOn = mood == value
                    Button {
                        withAnimation(.snappy(duration: 0.2)) { mood = isOn ? nil : value }
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: Self.symbols[value - 1]).font(.title3)
                                .symbolEffect(.bounce, value: isOn)
                            Text(Self.labels[value - 1]).font(.caption2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .foregroundStyle(isOn ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                        .background { SelectableChipBackground(isOn: isOn, hue: Theme.leafMid, shape: AnyShape(RoundedRectangle(cornerRadius: 12))) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title), \(Self.labels[value - 1])")
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
        .sensoryFeedback(.selection, trigger: mood)
    }
}

/// Edits how a logged session went. The amount stays; undo removes it.
struct SessionEditSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let bag: Bag
    @State var entry: UsageEntry

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Amount", value: entry.grams.formatted(.number.precision(.fractionLength(0...2))) + " g")
                    DatePicker("When", selection: $entry.date, in: ...Date.now)
                    LabeledContent("Bag", value: bag.displayName)
                }
                SessionDetailsSection(
                    method: $entry.method, moodBefore: $entry.moodBefore, moodAfter: $entry.moodAfter,
                    note: Binding(get: { entry.note ?? "" }, set: { entry.note = $0.isEmpty ? nil : $0 }),
                    withTobacco: $entry.withTobacco
                )
                Section {
                    Button("Undo this session", systemImage: "arrow.uturn.backward", role: .destructive) {
                        model.undoUse(entry, in: bag)
                        dismiss()
                    }
                } footer: {
                    Text("Puts the amount back in the bag.")
                }
            }
            .navigationTitle("Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", role: .cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") {
                        model.updateUse(entry, in: bag)
                        dismiss()
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        }
    }
}

/// This week's use against the optional weekly limit.
struct WeeklyCard: View {
    let summary: InventorySummary
    let edit: () -> Void
    @AppStorage(Notifier.weeklyLimitKey, store: SharedContainer.defaults) private var limit = 0.0

    var body: some View {
        Button(action: edit) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().stroke(Theme.leafMid.opacity(0.15), lineWidth: 8)
                    if limit > 0 {
                        Circle()
                            .trim(from: 0, to: min(1, summary.usedThisWeek / limit))
                            .stroke(summary.usedThisWeek >= limit ? AnyShapeStyle(.orange) : AnyShapeStyle(Theme.ring()), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    Image(systemName: "calendar").font(.subheadline).foregroundStyle(Theme.leafMid)
                }
                .frame(width: 48, height: 48)
                .animation(.spring(duration: 0.6), value: summary.usedThisWeek)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("This week").font(.headline).foregroundStyle(.primary)
                        Text("· \(summary.useFreeDaysThisWeek) of \(summary.daysSoFarThisWeek) days without use")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(limit > 0
                         ? String(localized: "\(summary.usedThisWeek.gramsLabel) of \(limit.gramsLabel)") + (summary.usedThisWeek >= limit ? String(localized: " · limit reached") : "")
                         : String(localized: "\(summary.usedThisWeek.gramsLabel) used · set a weekly limit"))
                        .font(.subheadline)
                        .foregroundStyle(summary.usedThisWeek >= limit && limit > 0 ? .orange : .secondary)
                        .contentTransition(.numericText())
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .glassCard()
    }
}

/// Weekly limit and reminders.
struct LimitsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Notifier.weeklyLimitKey, store: SharedContainer.defaults) private var limit = 0.0
    @AppStorage(Notifier.lowStashKey, store: SharedContainer.defaults) private var lowDays = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Weekly limit", isOn: Binding(get: { limit > 0 }, set: { on in
                        limit = on ? 3 : 0
                        if on { Task { _ = await Notifier.requestPermission() } }
                    }))
                    if limit > 0 {
                        Stepper(value: $limit, in: 0.5...50, step: 0.5) {
                            Text(limit.gramsLabel + String(localized: " per week")).monospacedDigit()
                        }
                    }
                } footer: {
                    Text("Weeks start on Monday. You get one notification when you reach the limit; nothing stops you logging.")
                }
                Section {
                    Toggle("Low stash reminder", isOn: Binding(get: { lowDays > 0 }, set: { on in
                        lowDays = on ? 5 : 0
                        if on { Task { _ = await Notifier.requestPermission() } }
                    }))
                    if lowDays > 0 {
                        Stepper("Below \(lowDays) days of supply", value: $lowDays, in: 1...30)
                    }
                } footer: {
                    Text("Based on your pace over the last 30 days.")
                }
            }
            .navigationTitle("Limits and reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") {
                        model.refreshShared()
                        dismiss()
                    }
                }
            }
        }
    }
}

/// A new version, a library update in progress, or a signature about to lapse.
struct UpdateNotices: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let updates = model.updates
        VStack(spacing: 12) {
            if let notice = updates.refreshNotice {
                card(symbol: "clock.badge.exclamationmark", hue: .orange,
                     title: refreshTitle(notice),
                     detail: String(localized: "Open SideStore and refresh Taima. Nothing is deleted when it lapses; it just won't open until you refresh."),
                     dismiss: updates.dismissRefreshNotice)
            }
            if let update = updates.availableUpdate {
                card(symbol: "arrow.down.app", hue: Theme.leafMid,
                     title: String(localized: "Taima \(update.version) is available"),
                     detail: (Locale.preferredLanguages.first?.hasPrefix("nl") == true ? "" : update.localizedDescription.map { $0 + "\n" } ?? "") + String(localized: "Update in SideStore. Install over the app; your data stays."),
                     dismiss: updates.dismissAppUpdate)
            }
        }
    }

    private func refreshTitle(_ notice: RefreshPolicy.Notice) -> String {
        switch notice {
        case .expiresSoon(let date): String(localized: "Taima stops opening \(date.formatted(.relative(presentation: .named)))")
        case .expired: String(localized: "Taima's signature has expired")
        }
    }

    private func card(symbol: String, hue: Color, title: String, detail: String, dismiss: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 12) {
            TintedIconTile(systemImage: symbol, hue: hue, size: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary).lineLimit(5)
            }
            Spacer(minLength: 0)
            Button("Dismiss", systemImage: "xmark", action: dismiss)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .frame(minWidth: 44, minHeight: 44)
        }
        .glassCard(tint: hue)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
