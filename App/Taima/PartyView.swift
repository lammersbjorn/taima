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
        .sensoryFeedback(.success, trigger: spin)
        .onAppear {
            guard !loaded else { return }
            settings = PartySettings.decode(stored.isEmpty ? nil : stored)
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
                            Text("\(player.points) pts" + (player.sjaak > 0 ? " · \(player.sjaak)× sjaak" : ""))
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
            if let way { Label(way.name, systemImage: way.symbol).foregroundStyle(.secondary) }
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
                    Label(way.name, systemImage: way.symbol)
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
            cardView(card, spin: spin, player: player)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func cardView(_ card: RuleCard, spin: PartySpin, player: Player?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(card.kind == .game ? "Game" : "House rule", systemImage: card.kind == .game ? "gamecontroller" : "text.book.closed")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.leaf)
                if card.intense {
                    Text("Intense").font(.caption.weight(.semibold)).foregroundStyle(.orange)
                }
            }
            Text(card.title).font(.title3.bold())
            Text(card.detail).font(.subheadline)
            if card.dealsPrompt, let letter = spin.letter {
                HStack(alignment: .center, spacing: 16) {
                    Text(String(letter))
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.leaf)
                        .contentTransition(.numericText())
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Category").font(.caption).foregroundStyle(.secondary)
                        Text(spin.category ?? "Anything").font(.headline)
                    }
                    Spacer()
                    Button("New letter", systemImage: "arrow.triangle.2.circlepath") { dealAgain() }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                }
                .accessibilityElement(children: .combine)
            }
            if card.id == "onemoretime" {
                Button("One more time", systemImage: "arrow.clockwise") { oneMoreTime() }
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
    private func oneMoreTime() {
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
                        Toggle(isOn: $way.enabled) { Label(way.name, systemImage: way.symbol) }
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
                                        Text(card.title).foregroundStyle(.primary)
                                        if card.intense { Text("Intense").font(.caption.weight(.semibold)).foregroundStyle(.orange) }
                                    }
                                    Text(card.kind == .game ? "Game · \(card.minPlayers)+ players" : "House rule")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            Toggle(card.title, isOn: $card.enabled).labelsHidden()
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
                    TextField("Letters", text: $settings.letters)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    ForEach(Array(settings.categories.enumerated()), id: \.offset) { index, _ in
                        TextField("Category", text: Binding(
                            get: { settings.categories.indices.contains(index) ? settings.categories[index] : "" },
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
                CardEditor(card: card, isNew: !settings.cards.contains { $0.id == card.id }) { saved in
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
    @State var card: RuleCard
    let isNew: Bool
    let onSave: (RuleCard) -> Void

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
                    Stepper("At least \(counted(card.minPlayers, "player"))", value: $card.minPlayers, in: 1...12)
                    Toggle("Deal a letter and category", isOn: $card.dealsPrompt)
                    Toggle("Intense", isOn: $card.intense)
                } footer: {
                    Text("Intense marks games that involve holding smoke or fast rounds.")
                }
            }
            .navigationTitle(isNew ? "New game or rule" : card.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", role: .cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") {
                        onSave(card)
                        dismiss()
                    }
                    .disabled(card.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
