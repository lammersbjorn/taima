import SwiftUI
import TaimaCore

/// Spin for a strain, a way to smoke, whose turn it is and a game or house
/// rule. Players, ways, cards, letters and categories are all editable.
struct RouletteView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("party.settings") private var stored = Data()
    @State private var settings = PartySettings()
    @State private var loaded = false
    @State private var spin: PartySpin?
    @State private var preview: (bag: Bag?, way: SmokeWay?)?
    @State private var spinning = false
    @State private var spins = 0
    @State private var showingPlayers = false
    @State private var showingCustomize = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                playersStrip
                if let spin, !spinning {
                    result(spin)
                } else if let preview {
                    previewCard(preview.bag, preview.way)
                } else {
                    intro
                }
            }
            .padding()
            .padding(.bottom, 80)
        }
        .safeAreaInset(edge: .bottom) {
            Button(spinning ? "Spinning…" : "Spin", systemImage: "dice.fill") { start() }
                .font(.headline)
                .buttonStyle(.glassProminent)
                .tint(Theme.solid)
                .controlSize(.extraLarge)
                .disabled(spinning || !canSpin)
                .symbolEffect(.rotate, value: spins)
                .padding(.bottom, 8)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Players", systemImage: "person.2") { showingPlayers = true }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Customize", systemImage: "slider.horizontal.3") { showingCustomize = true }
            }
        }
        .sheet(isPresented: $showingPlayers) { PlayersSheet(settings: $settings) }
        .sheet(isPresented: $showingCustomize) { CustomizeSheet(settings: $settings) }
        .sensoryFeedback(.selection, trigger: preview?.bag?.id)
        .sensoryFeedback(trigger: spin) { _, new in
            new?.isLegendary == true ? .impact(weight: .heavy, intensity: 1) : .success
        }
        .onAppear {
            guard !loaded else { return }
            settings = PartySettings.decode(stored.isEmpty ? nil : stored)
            #if DEBUG
            if ProcessInfo.processInfo.environment["TAIMA_LEGENDARY"] == "1" || UserDefaults.standard.bool(forKey: "debug.legendary") { settings.legendaryChance = 1 }
            #endif
            loaded = true
        }
        .onChange(of: settings) { _, new in stored = new.encoded ?? stored }
    }

    private var pool: [Bag] { settings.onlyStash ? model.bags.filter { $0.stock != .empty } : model.bags }

    private var canSpin: Bool {
        !pool.isEmpty || settings.ways.contains(where: \.enabled) || (settings.includesCards && settings.cards.contains(where: \.enabled))
    }

    // MARK: - Players

    @ViewBuilder private var playersStrip: some View {
        if settings.players.isEmpty {
            Button {
                showingPlayers = true
            } label: {
                Label("Add players to take turns and keep score", systemImage: "person.2.badge.plus")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(Theme.leafMid)
        } else {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(settings.players) { player in
                        let isTurn = spin?.playerID == player.id
                        VStack(spacing: 2) {
                            Text(player.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                            Text([String(localized: "\(player.points) pts"), player.legendaries > 0 ? "★\(player.legendaries)" : nil, player.sjaak > 0 ? String(localized: "\(player.sjaak)× sjaak") : nil].compactMap { $0 }.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .frame(minHeight: 44)
                        .background { SelectableChipBackground(isOn: isTurn, hue: Theme.leafMid, shape: AnyShape(Capsule())) }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(isTurn ? .isSelected : [])
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - Result

    private var intro: some View {
        VStack(spacing: 12) {
            Mascot(size: 120)
            Text("Spin for a strain, a way to smoke and a game.")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Add players for turns and points. Everything can be changed under Customize.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 30)
    }

    private func previewCard(_ bag: Bag?, _ way: SmokeWay?) -> some View {
        VStack(spacing: 12) {
            BagPhoto(name: bag?.mainPhoto)
                .frame(width: 150, height: 150)
                .clipShape(.rect(cornerRadius: Theme.mediaRadius))
            Text(bag?.displayName ?? " ").font(.title3.bold())
            if let way { Label(way.displayName, systemImage: way.symbol).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    @ViewBuilder private func result(_ spin: PartySpin) -> some View {
        let bag = spin.bagID.flatMap(model.bag(id:))
        let player = spin.playerID.flatMap { id in settings.players.first { $0.id == id } }
        if let player {
            Text("\(player.name)'s turn")
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        if bag != nil || spin.way != nil {
            VStack(spacing: 12) {
                if let bag {
                    NavigationLink(value: bag.id) {
                        VStack(spacing: 10) {
                            BagPhoto(name: bag.mainPhoto)
                                .frame(width: 150, height: 150)
                                .clipShape(.rect(cornerRadius: Theme.mediaRadius))
                            Text(bag.displayName).font(.title3.bold()).foregroundStyle(.primary).multilineTextAlignment(.center)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens it")
                    if let thc = bag.thc { Chip(title: "THC", value: thc.label, prominent: true) }
                }
                if let way = spin.way {
                    Label(way.displayName, systemImage: way.symbol)
                        .font(.headline)
                        .foregroundStyle(Theme.leaf)
                }
                if let bag, bag.stock != .empty, model.currentBagID != bag.id {
                    Button("Use this one", systemImage: "leaf") { withAnimation { model.open(bag) } }
                        .buttonStyle(.bordered)
                        .tint(Theme.leafMid)
                }
            }
            .frame(maxWidth: .infinity)
            .glassCard()
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
        if let card = spin.card {
            if card.legendary {
                LegendaryCard(card: card, combo: spin.combo, player: player,
                              done: { player.map { completeLegendary($0.id) } })
                    .id(spin)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            } else {
                cardView(card, spin: spin, player: player)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func cardView(_ card: RuleCard, spin: PartySpin, player: Player?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(card.kind == .game ? String(localized: "Game") : String(localized: "House rule"), systemImage: card.kind == .game ? "gamecontroller" : "text.book.closed")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.leaf)
                if card.intense {
                    Text("Intense").font(.caption.weight(.semibold)).foregroundStyle(.orange)
                }
            }
            Text(card.displayTitle).font(.title3.bold())
            Text(card.displayDetail).font(.subheadline)
            if card.dealsPrompt, let letter = spin.letter {
                HStack(alignment: .center, spacing: 16) {
                    Text(String(letter))
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.leaf)
                        .contentTransition(.numericText())
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Category").font(.caption).foregroundStyle(.secondary)
                        Text(spin.category.map(PartyText.display) ?? String(localized: "Anything")).font(.headline)
                    }
                    Spacer()
                    Button("New letter", systemImage: "arrow.triangle.2.circlepath") { dealAgain() }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                }
                .accessibilityElement(children: .combine)
            }
            if card.id == "sameagain" {
                Button("Same again", systemImage: "arrow.clockwise") { sameAgain() }
                    .buttonStyle(.bordered)
                    .tint(Theme.leafMid)
                    .controlSize(.large)
            }
            if card.kind == .game, settings.players.count >= 2 {
                scoring(player: player)
            }
        }
        .glassCard()
    }

    /// Points for the winner, and the sjaak for whoever was too slow.
    private func scoring(player: Player?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Who won this round?").font(.caption).foregroundStyle(.secondary)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(settings.players) { winner in
                        Button("+1 \(winner.name)") { award(winner.id) }
                            .buttonStyle(.bordered)
                            .tint(Theme.leafMid)
                    }
                    if let player {
                        Button("\(player.name) is sjaak") { markSjaak(player.id) }
                            .buttonStyle(.bordered)
                            .tint(.orange)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(.top, 4)
    }

    // MARK: - Actions

    private func start() {
        spinning = true
        spins += 1
        let previous = spin
        let enabledWays = settings.ways.filter(\.enabled)
        let bags = pool
        Task {
            for step in 0..<10 {
                withAnimation(.spring(duration: 0.22)) { preview = (bags.randomElement(), enabledWays.randomElement()) }
                try? await Task.sleep(for: .milliseconds(60 + step * 22))
            }
            withAnimation(.spring(duration: 0.45, bounce: 0.3)) {
                spin = PartyEngine.spin(settings, bags: model.bags, after: previous)
                preview = nil
                spinning = false
            }
        }
    }

    private func dealAgain() {
        let (letter, category) = PartyEngine.prompt(settings)
        withAnimation(.snappy) {
            spin?.letter = letter
            spin?.category = category
        }
    }

    /// Same strain and way; the turn and the card move on.
    private func sameAgain() {
        guard let current = spin else { return }
        var next = PartyEngine.spin(settings, bags: model.bags, after: current)
        next.bagID = current.bagID
        next.way = current.way
        withAnimation(.spring(duration: 0.45, bounce: 0.3)) { spin = next }
    }

    private func award(_ id: UUID) {
        guard let index = settings.players.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.snappy) { settings.players[index].points += 1 }
    }

    /// A legendary challenge taken: three points and a star.
    private func completeLegendary(_ id: UUID) {
        guard let index = settings.players.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.snappy) {
            settings.players[index].points += 3
            settings.players[index].legendaries += 1
        }
    }

    private func markSjaak(_ id: UUID) {
        guard let index = settings.players.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.snappy) { settings.players[index].sjaak += 1 }
    }
}

// MARK: - Players

private struct PlayersSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var settings: PartySettings
    @State private var newName = ""
    @State private var confirmingReset = false
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("Name", text: $newName)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .focused($focused)
                            .onSubmit(add)
                        Button("Add", action: add)
                            .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } footer: {
                    Text("Turns go round in this order. Drag to change it.")
                }
                if !settings.players.isEmpty {
                    Section("Players") {
                        ForEach($settings.players) { $player in
                            HStack {
                                TextField("Name", text: $player.name)
                                Stepper("\(player.points) pts", value: $player.points, in: 0...999)
                                    .fixedSize()
                                    .monospacedDigit()
                            }
                        }
                        .onDelete { settings.players.remove(atOffsets: $0) }
                        .onMove { settings.players.move(fromOffsets: $0, toOffset: $1) }
                    }
                    Section {
                        Button("Reset scores", systemImage: "arrow.counterclockwise") { confirmingReset = true }
                    }
                }
            }
            .navigationTitle("Players")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
            .confirmationDialog("Reset all scores?", isPresented: $confirmingReset, titleVisibility: .visible) {
                Button("Reset scores", role: .destructive) {
                    for index in settings.players.indices {
                        settings.players[index].points = 0
                        settings.players[index].sjaak = 0
                    }
                }
            }
            .onAppear { if settings.players.isEmpty { focused = true } }
        }
    }

    private func add() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        withAnimation { settings.players.append(Player(name: name)) }
        newName = ""
    }
}

// MARK: - Customize

private struct CustomizeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var settings: PartySettings
    @State private var newWay = ""
    @State private var newCategory = ""
    @State private var editing: RuleCard?
    @State private var confirmingDefaults = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Only what's in my stash", isOn: $settings.onlyStash)
                    Toggle("Draw a game or rule", isOn: $settings.includesCards)
                }

                Section {
                    ForEach($settings.ways) { $way in
                        Toggle(isOn: $way.enabled) { Label(way.displayName, systemImage: way.symbol) }
                            .deleteDisabled(way.builtIn)
                    }
                    .onDelete { offsets in settings.ways.remove(atOffsets: offsets) }
                    HStack {
                        TextField("Add a way, like a bucket bong", text: $newWay)
                            .onSubmit(addWay)
                        Button("Add", action: addWay).disabled(newWay.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("Ways of smoking")
                } footer: {
                    Text("Pure means without tobacco, which Trimbos recommends.")
                }

                Section {
                    ForEach($settings.cards) { $card in
                        HStack {
                            Button {
                                editing = card
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(card.displayTitle).foregroundStyle(.primary)
                                        if card.legendary { Text("Legendary").font(.caption.weight(.semibold)).foregroundStyle(LegendaryCard.goldText) }
                                        if card.intense { Text("Intense").font(.caption.weight(.semibold)).foregroundStyle(.orange) }
                                    }
                                    Text(card.kind == .game ? String(localized: "Game · \(card.minPlayers)+ players") : String(localized: "House rule"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            Toggle(card.displayTitle, isOn: $card.enabled).labelsHidden()
                        }
                        .deleteDisabled(card.builtIn)
                    }
                    .onDelete { offsets in settings.cards.remove(atOffsets: offsets) }
                    Button("Add your own game or rule", systemImage: "plus") {
                        editing = RuleCard(title: "", detail: "")
                    }
                } header: {
                    Text("Games and house rules")
                } footer: {
                    Text("Tap one to change its words. Intense games involve holding smoke and are off until you switch them on. Holding longer adds nothing but strain on your lungs, and anyone can always pass.")
                }

                Section {
                    Toggle("Legendary pulls", isOn: Binding(
                        get: { settings.legendaryChance > 0 },
                        set: { settings.legendaryChance = $0 ? 1.0 / 15 : 0 }
                    ))
                    if settings.legendaryChance > 0 {
                        VStack(alignment: .leading) {
                            Text("About 1 in \(Int((1 / settings.legendaryChance).rounded())) spins")
                                .monospacedDigit()
                            Slider(value: $settings.legendaryChance, in: 0.02...0.25)
                                .tint(LegendaryCard.gold)
                                .accessibilityLabel("How often")
                        }
                    }
                } header: {
                    Text("Legendary pulls")
                } footer: {
                    Text("A rare card with a bigger challenge, like a combo of two ways, worth 3 points. Mark any game or rule as legendary in its editor. Skipping one is always fine.")
                }

                Section {
                    TextField("Letters", text: $settings.letters)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    ForEach(Array(settings.categories.enumerated()), id: \.offset) { index, _ in
                        TextField("Category", text: Binding(
                            get: { settings.categories.indices.contains(index) ? PartyText.display(settings.categories[index]) : "" },
                            set: { if settings.categories.indices.contains(index) { settings.categories[index] = $0 } }
                        ))
                    }
                    .onDelete { settings.categories.remove(atOffsets: $0) }
                    HStack {
                        TextField("Add a category", text: $newCategory).onSubmit(addCategory)
                        Button("Add", action: addCategory).disabled(newCategory.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("Bim Bam Baap letters and categories")
                }

                Section {
                    Button("Restore the original games and ways", systemImage: "arrow.counterclockwise") { confirmingDefaults = true }
                }
            }
            .navigationTitle("Customize")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
            .sheet(item: $editing) { card in
                CardEditor(original: card, isNew: !settings.cards.contains { $0.id == card.id }) { saved in
                    if let index = settings.cards.firstIndex(where: { $0.id == saved.id }) {
                        settings.cards[index] = saved
                    } else {
                        settings.cards.append(saved)
                    }
                }
            }
            .confirmationDialog("Restore the original games and ways?", isPresented: $confirmingDefaults, titleVisibility: .visible) {
                Button("Restore", role: .destructive) {
                    let players = settings.players
                    settings = PartySettings(players: players)
                }
            } message: {
                Text("Your own games, ways, letters and categories are replaced. Players and scores stay.")
            }
        }
    }

    private func addWay() {
        let name = newWay.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        settings.ways.append(SmokeWay(name: name))
        newWay = ""
    }

    private func addCategory() {
        let name = newCategory.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        settings.categories.append(name)
        newCategory = ""
    }
}

private struct CardEditor: View {
    @Environment(\.dismiss) private var dismiss
    let original: RuleCard
    @State private var card: RuleCard
    let isNew: Bool
    let onSave: (RuleCard) -> Void

    /// Built-in text is edited in the person's language; unchanged text
    /// stays stored in English, so it keeps following the language.
    init(original: RuleCard, isNew: Bool, onSave: @escaping (RuleCard) -> Void) {
        self.original = original
        self.isNew = isNew
        self.onSave = onSave
        var shown = original
        shown.title = original.displayTitle
        shown.detail = original.displayDetail
        _card = State(initialValue: shown)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $card.title)
                    TextField("How it works", text: $card.detail, axis: .vertical)
                        .lineLimit(3...10)
                }
                Section {
                    Picker("Kind", selection: $card.kind) {
                        Text("Game").tag(RuleCard.Kind.game)
                        Text("House rule").tag(RuleCard.Kind.rule)
                    }
                    Stepper(String(localized: "At least \(card.minPlayers) players"), value: $card.minPlayers, in: 1...12)
                    Toggle("Deal a letter and category", isOn: $card.dealsPrompt)
                    Toggle("Legendary", isOn: $card.legendary)
                    if card.legendary {
                        Toggle("Combine two ways of smoking", isOn: $card.dealsCombo)
                    }
                    Toggle("Intense", isOn: $card.intense)
                } footer: {
                    Text("Legendary cards are rare pulls worth 3 points. Intense marks games that involve holding smoke or fast rounds.")
                }
            }
            .navigationTitle(isNew ? String(localized: "New game or rule") : card.displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", role: .cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") {
                        var saved = card
                        if saved.title == original.displayTitle { saved.title = original.title }
                        if saved.detail == original.displayDetail { saved.detail = original.detail }
                        onSave(saved)
                        dismiss()
                    }
                    .disabled(card.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Legendary

/// A rare pull: a gold card, the combo spelled out, and three points for
/// taking it on. Passing costs nothing.
struct LegendaryCard: View {
    static let gold = Color(red: 0.96, green: 0.74, blue: 0.22)
    /// Behind white text: about 5:1 in both modes.
    static let goldFill = Color(red: 0.50, green: 0.32, blue: 0.0)
    /// Gold dark enough for text on light cards.
    static let goldText = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.98, green: 0.80, blue: 0.35, alpha: 1)
            : UIColor(red: 0.60, green: 0.40, blue: 0.02, alpha: 1)
    })

    let card: RuleCard
    let combo: [SmokeWay]
    let player: Player?
    let done: () -> Void
    @State private var taken = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Legendary pull", systemImage: "sparkles")
                .font(.caption.weight(.heavy))
                .textCase(.uppercase)
                .foregroundStyle(Self.goldText)
                .symbolEffect(.bounce, options: .nonRepeating, value: card.id)
            Text(card.displayTitle).font(.title2.bold())
            if combo.count == 2 {
                HStack(spacing: 10) {
                    comboPart(combo[0])
                    Image(systemName: "plus").font(.title3.weight(.bold)).foregroundStyle(Self.goldText)
                    comboPart(combo[1])
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(localized: "\(combo[0].displayName) and \(combo[1].displayName)"))
            }
            Text(card.displayDetail).font(.subheadline)
            if let player {
                HStack(spacing: 8) {
                    Button(taken ? "+3 for \(player.name)" : "\(player.name) did it, +3", systemImage: taken ? "checkmark" : "star.fill") {
                        guard !taken else { return }
                        taken = true
                        done()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Self.goldFill)
                    .controlSize(.large)
                    .disabled(taken)
                    Text("or pass, no penalty")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .glassCard()
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(AngularGradient(colors: [Self.gold, .orange, Self.gold.opacity(0.4), Self.gold], center: .center), lineWidth: 2.5)
        }
        .shadow(color: Self.gold.opacity(0.35), radius: reduceMotion ? 6 : 14)
        .phaseAnimator(reduceMotion ? [false] : [false, true]) { content, glowing in
            content.scaleEffect(glowing ? 1.01 : 1)
        } animation: { _ in .easeInOut(duration: 1.4) }
        .sensoryFeedback(.success, trigger: taken)
    }

    private func comboPart(_ way: SmokeWay) -> some View {
        Label(way.displayName, systemImage: way.symbol)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .background(Self.gold.opacity(0.18), in: .capsule)
    }
}
