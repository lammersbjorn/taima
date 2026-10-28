import SwiftUI
import TaimaCore

/// Session games: spin for a strain, a way to smoke, whose turn it is and a
/// game, or pick a game yourself. Players, cards, ways, letters and
/// categories are all editable. Nothing here is logged against the stash.
struct RouletteView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("party.settings") private var stored = Data()
    @State private var settings = PartySettings()
    @State private var loaded = false
    @State private var spin: PartySpin?
    @State private var preview: (bag: Bag?, way: SmokeWay?)?
    @State private var spinning = false
    @State private var spins = 0
    @State private var revealing = false
    @State private var tableRule: TableRule?
    @State private var showingPlayers = false
    @State private var showingCustomize = false

    struct TableRule: Equatable { var text: String; var spinsLeft: Int }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PlayersStrip(players: settings.players, turn: spin?.playerID) { showingPlayers = true }
                if let tableRule {
                    TableRuleBanner(rule: tableRule) { withAnimation(.snappy) { self.tableRule = nil } }
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                spinArea
                GameLibrary(settings: $settings)
            }
            .padding()
            .padding(.bottom, 90)
        }
        .scrollDismissesKeyboard(.immediately)
        .safeAreaInset(edge: .bottom) {
            Button {
                start()
            } label: {
                Label(spinning ? String(localized: "Spinning…") : String(localized: "Spin"), systemImage: "dice.fill")
                    .font(.headline)
                    .padding(.horizontal, 18)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.solid)
            .controlSize(.extraLarge)
            .disabled(spinning)
            .symbolEffect(.rotate, value: spins)
            .padding(.bottom, 8)
        }
        .overlay {
            if revealing {
                LegendaryReveal()
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
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

    // MARK: - Spin

    @ViewBuilder private var spinArea: some View {
        if let preview, spinning {
            SpinPreview(bag: preview.bag, way: preview.way)
        } else if let spin {
            SpinResult(spin: spin, settings: $settings,
                       nextPrompt: { dealAgain() },
                       sameAgain: { sameAgain() })
        } else {
            VStack(spacing: 6) {
                Text("Spin for a strain, a way to smoke and a game.")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text("Or pick a game below and play it right away.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    private func start() {
        spinning = true
        spins += 1
        let previous = spin
        let enabledWays = settings.ways.filter(\.enabled)
        let bags = pool
        Task {
            for step in 0..<9 {
                withAnimation(.spring(duration: 0.2)) { preview = (bags.randomElement(), enabledWays.randomElement()) }
                try? await Task.sleep(for: .milliseconds(55 + step * 22))
            }
            let next = PartyEngine.spin(settings, bags: model.bags, after: previous)
            if next.isLegendary {
                // A beat of suspense before a legendary card lands.
                withAnimation(.easeOut(duration: 0.2)) { revealing = true }
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 400 : 1100))
            }
            withAnimation(.spring(duration: 0.5, bounce: 0.3)) {
                spin = next
                preview = nil
                spinning = false
                revealing = false
                settings.spinsSinceLegendary = next.isLegendary ? 0 : settings.spinsSinceLegendary + 1
                advanceTableRule(with: next)
            }
        }
    }

    /// A table rule card starts a rule for five spins; every other spin counts it down.
    private func advanceTableRule(with spin: PartySpin) {
        if spin.card?.deck == .tableRule, let text = spin.prompts.first {
            tableRule = TableRule(text: text, spinsLeft: 5)
        } else if var rule = tableRule {
            rule.spinsLeft -= 1
            tableRule = rule.spinsLeft > 0 ? rule : nil
        }
    }

    private func dealAgain() {
        guard let deck = spin?.card?.deck, var current = spin else { return }
        PartyEngine.deal(deck, settings: settings, into: &current)
        withAnimation(.snappy) { spin = current }
    }

    /// Same strain and way; the turn and the card move on.
    private func sameAgain() {
        guard let current = spin else { return }
        var next = PartyEngine.spin(settings, bags: model.bags, after: current)
        next.bagID = current.bagID
        next.way = current.way
        withAnimation(.spring(duration: 0.45, bounce: 0.3)) { spin = next }
    }
}

// MARK: - Spin pieces

private struct SpinPreview: View {
    let bag: Bag?
    let way: SmokeWay?

    var body: some View {
        HStack(spacing: 14) {
            BagPhoto(name: bag?.mainPhoto)
                .frame(width: 64, height: 64)
                .clipShape(.rect(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
                Text(bag?.displayName ?? " ").font(.headline).lineLimit(1)
                if let way { Label(way.displayName, systemImage: way.symbol).font(.subheadline).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 0)
        }
        .glassCard()
    }
}

private struct SpinResult: View {
    @Environment(AppModel.self) private var model
    let spin: PartySpin
    @Binding var settings: PartySettings
    let nextPrompt: () -> Void
    let sameAgain: () -> Void

    var body: some View {
        let bag = spin.bagID.flatMap(model.bag(id:))
        let player = spin.playerID.flatMap { id in settings.players.first { $0.id == id } }
        VStack(alignment: .leading, spacing: 12) {
            if let player {
                Text("\(player.name)'s turn")
                    .font(.title2.bold())
                    .contentTransition(.opacity)
            }
            if bag != nil || spin.way != nil {
                HStack(spacing: 14) {
                    if let bag {
                        NavigationLink(value: bag.id) {
                            BagPhoto(name: bag.mainPhoto)
                                .frame(width: 72, height: 72)
                                .clipShape(.rect(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(bag.displayName)
                        .accessibilityHint("Opens it")
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        if let bag {
                            Text(bag.displayName).font(.headline).lineLimit(2)
                            if let thc = bag.thc { Text("THC \(thc.label)").font(.caption).foregroundStyle(.secondary) }
                        }
                        if let way = spin.way {
                            Label(way.displayName, systemImage: way.symbol)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.leaf)
                        }
                    }
                    Spacer(minLength: 0)
                    if let bag, bag.stock != .empty, model.currentBagID != bag.id {
                        Button("Use this one", systemImage: "leaf") { withAnimation { model.open(bag) } }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.bordered)
                            .tint(Theme.leafMid)
                            .controlSize(.large)
                    }
                }
                .glassCard()
            }
            if let card = spin.card {
                GameCardView(card: card, spin: spin, player: player, settings: $settings,
                             nextPrompt: card.deck == nil ? nil : nextPrompt,
                             sameAgain: card.id == "sameagain" ? sameAgain : nil)
                    .id(spin)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

private struct TableRuleBanner: View {
    let rule: RouletteView.TableRule
    let end: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "scroll.fill")
                .font(.title3)
                .foregroundStyle(GameStyle.ruleHue)
            VStack(alignment: .leading, spacing: 2) {
                Text("Table rule · \(String(localized: "\(rule.spinsLeft) spins left"))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(rule.text).font(.subheadline.weight(.semibold))
            }
            Spacer(minLength: 0)
            Button("End rule", systemImage: "xmark", action: end)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.leading, 14)
        .padding(.vertical, 6)
        .background(GameStyle.ruleHue.opacity(0.12), in: .rect(cornerRadius: Theme.cardRadius))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Players strip

private struct PlayersStrip: View {
    let players: [Player]
    let turn: UUID?
    let edit: () -> Void

    var body: some View {
        if players.isEmpty {
            Button(action: edit) {
                Label("Add players for turns and points", systemImage: "person.2.badge.plus")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(Theme.leafMid)
        } else {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(players) { player in
                        let isTurn = turn == player.id
                        VStack(spacing: 2) {
                            Text(player.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                            Text([String(localized: "\(player.points) pts"), player.legendaries > 0 ? "★\(player.legendaries)" : nil].compactMap { $0 }.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .frame(minHeight: 44)
                        .background { SelectableChipBackground(isOn: isTurn, hue: Theme.leafMid, shape: AnyShape(Capsule())) }
                        .scaleEffect(isTurn ? 1.05 : 1)
                        .animation(.snappy, value: isTurn)
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(isTurn ? .isSelected : [])
                    }
                    Button("Players", systemImage: "pencil", action: edit)
                        .labelStyle(.iconOnly)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }
}

// MARK: - Library

/// Every game, ready to start by hand.
private struct GameLibrary: View {
    @Binding var settings: PartySettings

    var body: some View {
        let playing = max(settings.players.count, 1)
        let cards = settings.cards.filter(\.enabled)
        let games = cards.filter { !$0.legendary && $0.kind == .game }
        let rules = cards.filter { !$0.legendary && $0.kind == .rule }
        let legendary = cards.filter(\.legendary)
        VStack(alignment: .leading, spacing: 18) {
            section(String(localized: "Games"), games, playing: playing)
            if !rules.isEmpty { section(String(localized: "House rules"), rules, playing: playing) }
            if !legendary.isEmpty { section(String(localized: "Legendary"), legendary, playing: playing) }
        }
    }

    private func section(_ title: String, _ cards: [RuleCard], playing: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title3.bold())
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 158), spacing: 12, alignment: .top)], spacing: 12) {
                ForEach(cards) { card in
                    // A direct destination: this screen is itself pushed without a value.
                    NavigationLink {
                        GamePlayView(card: card, settings: $settings)
                    } label: {
                        GameTile(card: card, tooFewPlayers: card.minPlayers > playing && playing > 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct GameTile: View {
    let card: RuleCard
    let tooFewPlayers: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                GameIcon(card: card, size: 38)
                Spacer()
                if card.deck != nil {
                    Image(systemName: "rectangle.stack.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            Text(card.displayTitle).font(.headline).foregroundStyle(.primary).lineLimit(2)
            if let hook = card.displayHook {
                Text(hook).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 0)
            Text(card.kind == .game ? String(localized: "\(card.minPlayers)+ players") : String(localized: "House rule"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(tooFewPlayers ? AnyShapeStyle(.orange) : AnyShapeStyle(.tertiary))
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .glassCard(padding: 14)
        .accessibilityElement(children: .combine)
        .accessibilityHint(card.deck != nil ? String(localized: "Deals new content each round") : "")
        .overlay {
            if card.legendary {
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .strokeBorder(GameStyle.gold.opacity(0.7), lineWidth: 1.5)
            }
        }
        .contentShape(.rect)
    }
}

// MARK: - Playing a game by hand

private struct GamePlayView: View {
    let card: RuleCard
    @Binding var settings: PartySettings
    @State private var dealt = PartySpin()
    @State private var turn: Int = 0

    var body: some View {
        let player = settings.players.isEmpty ? nil : settings.players[min(turn, settings.players.count - 1)]
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let player {
                    HStack {
                        Text("\(player.name)'s turn").font(.title2.bold()).contentTransition(.opacity)
                        Spacer()
                        Button("Next player", systemImage: "arrow.right.circle.fill") {
                            withAnimation(.snappy) { turn = (turn + 1) % settings.players.count }
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.leafMid)
                    }
                }
                GameCardView(card: card, spin: dealt, player: player, settings: $settings,
                             nextPrompt: card.deck == nil && !card.dealsCombo ? nil : { deal() },
                             sameAgain: nil)
            }
            .padding()
        }
        .background(GlowBackground(hue: GameStyle.hue(for: card)))
        .navigationTitle(card.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if dealt.prompts.isEmpty && dealt.letter == nil && dealt.combo.isEmpty { deal() } }
        .sensoryFeedback(.selection, trigger: turn)
    }

    private func deal() {
        var next = dealt
        next.card = card
        if let deck = card.deck { PartyEngine.deal(deck, settings: settings, into: &next) }
        if card.dealsCombo {
            var rng = SystemRandomNumberGenerator()
            next.combo = PartyEngine.combo(settings, using: &rng)
        }
        withAnimation(.snappy) { dealt = next }
    }
}

// MARK: - The card

enum GameStyle {
    static let gold = Color(red: 0.96, green: 0.74, blue: 0.22)
    /// Behind white text: about 5:1 in both modes.
    static let goldFill = Color(red: 0.50, green: 0.32, blue: 0.0)
    /// Gold dark enough for text on light cards.
    static let goldText = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.98, green: 0.80, blue: 0.35, alpha: 1)
            : UIColor(red: 0.60, green: 0.40, blue: 0.02, alpha: 1)
    })
    static let ruleHue = Color.indigo

    static func hue(for card: RuleCard) -> Color {
        card.legendary ? gold : card.kind == .rule ? ruleHue : Theme.leafMid
    }

    static func symbol(for card: RuleCard) -> String {
        let symbols: [String: String] = [
            "bimbambaap": "textformat.abc", "onemoretime": "music.note", "neverhave": "hand.raised.fill",
            "wouldyourather": "arrow.left.arrow.right", "wievanons": "hand.point.up.left.fill", "hotseat": "flame.fill",
            "debate": "megaphone.fill", "conspiracy": "eye.fill", "oneword": "text.bubble.fill", "explain": "questionmark.bubble.fill",
            "charades": "theatermasks.fill", "categories": "list.bullet", "rhyme": "music.mic", "straightface": "face.smiling",
            "medusa": "eyes", "impressions": "person.wave.2.fill", "raadnummer": "music.quarternote.3", "twotruths": "checkmark.seal.fill",
            "watzieje": "binoculars.fill", "vakantie": "suitcase.fill", "island": "beach.umbrella.fill", "bingo": "square.grid.3x3.fill",
            "blaas": "circle.dashed", "rollen": "scribble.variable", "jammin": "music.note.list", "321": "timer", "maxxen": "lungs.fill",
            "sameagain": "arrow.clockwise", "tablerule": "scroll.fill", "legend.combo": "plus.circle.fill", "legend.bongjoint": "drop.circle.fill",
            "legend.king": "crown.fill", "legend.golden": "star.circle.fill", "legend.plottwist": "shuffle", "legend.chef": "frying.pan.fill",
        ]
        return symbols[card.id] ?? (card.legendary ? "sparkles" : card.kind == .rule ? "text.book.closed.fill" : "gamecontroller.fill")
    }
}

struct GameIcon: View {
    let card: RuleCard
    var size: CGFloat = 38

    var body: some View {
        let hue = GameStyle.hue(for: card)
        Image(systemName: GameStyle.symbol(for: card))
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(card.legendary ? GameStyle.goldText : hue)
            .frame(width: size, height: size)
            .background(hue.opacity(0.16), in: .rect(cornerRadius: size * 0.3, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// One game, the same on the spin and when played by hand: what was dealt
/// is the centrepiece, then the steps and who smokes.
private struct GameCardView: View {
    let card: RuleCard
    let spin: PartySpin
    let player: Player?
    @Binding var settings: PartySettings
    let nextPrompt: (() -> Void)?
    let sameAgain: (() -> Void)?
    @State private var showingSteps = true
    @State private var taken = false
    @State private var peeking = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let hue = GameStyle.hue(for: card)
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                GameIcon(card: card, size: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text(kindLabel)
                        .font(.caption.weight(.heavy))
                        .textCase(.uppercase)
                        .foregroundStyle(card.legendary ? GameStyle.goldText : hue)
                    Text(card.displayTitle).font(.title2.bold())
                }
                Spacer(minLength: 0)
                if card.intense {
                    Text("Intense")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange.opacity(0.14), in: .capsule)
                }
            }
            if let hook = card.displayHook {
                Text(hook).font(.headline).italic().foregroundStyle(.secondary)
            }
            dealtContent(hue: hue)
            DisclosureGroup(isExpanded: $showingSteps) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(card.displaySteps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 20, height: 20)
                                .background(card.legendary ? GameStyle.goldFill : hue == Theme.leafMid ? Theme.solid : hue, in: .circle)
                            Text(step).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, 6)
            } label: {
                Text("How to play").font(.subheadline.weight(.semibold))
            }
            .tint(.primary)
            if let puff = card.displayPuff {
                Label {
                    Text("Puff: \(puff)").font(.subheadline.weight(.semibold))
                } icon: {
                    Image(systemName: "leaf.fill").foregroundStyle(Theme.leafMid)
                }
            }
            actions
            Text("Passing is always fine.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .glassCard()
        .overlay {
            if card.legendary {
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .strokeBorder(AngularGradient(colors: [GameStyle.gold, .orange, GameStyle.gold.opacity(0.4), GameStyle.gold], center: .center), lineWidth: 2.5)
            }
        }
        .shadow(color: card.legendary ? GameStyle.gold.opacity(0.35) : .clear, radius: reduceMotion ? 6 : 14)
        .sensoryFeedback(.success, trigger: taken)
    }

    private var kindLabel: String {
        card.legendary ? String(localized: "Legendary pull") : card.kind == .rule ? String(localized: "House rule") : String(localized: "Game")
    }

    @ViewBuilder private func dealtContent(hue: Color) -> some View {
        if card.dealsCombo, spin.combo.count == 2 {
            HStack(spacing: 10) {
                comboPart(spin.combo[0])
                Image(systemName: "plus").font(.title3.weight(.bold)).foregroundStyle(GameStyle.goldText)
                comboPart(spin.combo[1])
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "\(spin.combo[0].displayName) and \(spin.combo[1].displayName)"))
        }
        if card.deck == .letters, let letter = spin.letter {
            HStack(alignment: .center, spacing: 16) {
                Text(String(letter))
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .foregroundStyle(hue)
                    .contentTransition(.numericText())
                VStack(alignment: .leading, spacing: 4) {
                    Text("Category").font(.caption).foregroundStyle(.secondary)
                    Text(spin.category.map(PartyText.display) ?? String(localized: "Anything")).font(.title3.weight(.semibold))
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(hue.opacity(0.1), in: .rect(cornerRadius: 18))
            .accessibilityElement(children: .combine)
        } else if !spin.prompts.isEmpty, card.deck?.isSecret == true, !peeking {
            // Charades, explain and hum: the rest of the table must not see it.
            Button {
                withAnimation(.snappy) { peeking = true }
            } label: {
                Label("Only you: tap to peek", systemImage: "eye.slash.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 64)
            }
            .buttonStyle(.bordered)
            .tint(hue)
        } else if !spin.prompts.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(spin.prompts.enumerated()), id: \.offset) { _, prompt in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        if spin.prompts.count > 1 { Image(systemName: "square").font(.subheadline).foregroundStyle(hue) }
                        Text(prompt)
                            .font(spin.prompts.count > 1 ? .body.weight(.semibold) : .title3.weight(.bold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(hue.opacity(0.1), in: .rect(cornerRadius: 18))
            .contentTransition(.opacity)
            .onTapGesture { if card.deck?.isSecret == true { withAnimation(.snappy) { peeking = false } } }
            .accessibilityHint(card.deck?.isSecret == true ? String(localized: "Tap to hide it again") : "")
        }
    }

    @ViewBuilder private var actions: some View {
        let hasPrompt = card.deck != nil || card.dealsCombo
        HStack(spacing: 8) {
            if hasPrompt, let nextPrompt {
                Button(card.deck == .letters ? String(localized: "New letter") : String(localized: "Next"), systemImage: "arrow.triangle.2.circlepath") {
                    peeking = false
                    nextPrompt()
                }
                    .buttonStyle(.bordered)
                    .tint(GameStyle.hue(for: card))
                    .controlSize(.large)
            }
            if let sameAgain {
                Button("Same again", systemImage: "arrow.clockwise", action: sameAgain)
                    .buttonStyle(.bordered)
                    .tint(GameStyle.ruleHue)
                    .controlSize(.large)
            }
        }
        if card.legendary, let player {
            Button(taken ? String(localized: "+3 for \(player.name)") : String(localized: "\(player.name) did it, +3"), systemImage: taken ? "checkmark" : "star.fill") {
                guard !taken, let index = settings.players.firstIndex(where: { $0.id == player.id }) else { return }
                taken = true
                withAnimation(.snappy) {
                    settings.players[index].points += 3
                    settings.players[index].legendaries += 1
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(GameStyle.goldFill)
            .controlSize(.large)
            .disabled(taken)
        } else if card.kind == .game, settings.players.count >= 2 {
            VStack(alignment: .leading, spacing: 6) {
                Text("Who won this round?").font(.caption).foregroundStyle(.secondary)
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(settings.players) { winner in
                            Button("+1 \(winner.name)") { award(winner.id) }
                                .buttonStyle(.bordered)
                                .tint(Theme.leafMid)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private func comboPart(_ way: SmokeWay) -> some View {
        Label(way.displayName, systemImage: way.symbol)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .background(GameStyle.gold.opacity(0.18), in: .capsule)
    }

    private func award(_ id: UUID) {
        guard let index = settings.players.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.snappy) { settings.players[index].points += 1 }
    }
}

/// The moment before a legendary card lands.
private struct LegendaryReveal: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            RadialGradient(colors: [GameStyle.gold.opacity(0.75), .clear], center: .center, startRadius: 10, endRadius: shown ? 420 : 60)
                .ignoresSafeArea()
            VStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 64, weight: .bold))
                    .symbolEffect(.bounce, options: .repeat(2), value: shown)
                Text("Legendary!")
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
            }
            .foregroundStyle(.white)
            .shadow(color: GameStyle.gold, radius: 20)
            .scaleEffect(shown || reduceMotion ? 1 : 0.4)
        }
        .onAppear { withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.6, bounce: 0.45)) { shown = true } }
        .sensoryFeedback(.impact(weight: .heavy), trigger: shown)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Legendary pull")
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
                                HStack(spacing: 12) {
                                    GameIcon(card: card, size: 34)
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(card.displayTitle).foregroundStyle(.primary)
                                            if card.intense { Text("Intense").font(.caption.weight(.semibold)).foregroundStyle(.orange) }
                                        }
                                        Text(card.displayHook ?? (card.kind == .game ? String(localized: "Game · \(card.minPlayers)+ players") : String(localized: "House rule")))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
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
                                .tint(GameStyle.gold)
                                .accessibilityLabel("How often")
                        }
                    }
                } header: {
                    Text("Legendary pulls")
                } footer: {
                    Text("A rare gold card worth 3 points. If none has come up in 20 spins, the next one is legendary. Mark any game or rule as legendary in its editor. Skipping one is always fine.")
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
    @State private var hook: String
    @State private var puff: String
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
        _hook = State(initialValue: original.displayHook ?? "")
        _puff = State(initialValue: original.displayPuff ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $card.title)
                    TextField("One line that sells it", text: $hook)
                } header: {
                    Text("Card")
                }
                Section {
                    TextField("One step per line", text: $card.detail, axis: .vertical)
                        .lineLimit(3...12)
                    TextField("Who smokes, like \"The winner\"", text: $puff)
                } header: {
                    Text("How to play")
                } footer: {
                    Text("Short steps in the imperative read best, such as \"Point at someone on three.\"")
                }
                Section {
                    Picker("Kind", selection: $card.kind) {
                        Text("Game").tag(RuleCard.Kind.game)
                        Text("House rule").tag(RuleCard.Kind.rule)
                    }
                    Picker("Deals each round", selection: Binding(get: { card.deck }, set: { card.deck = $0 })) {
                        Text("Nothing").tag(PromptDeck?.none)
                        ForEach(PromptDeck.allCases) { deck in
                            Text(deck.label).tag(PromptDeck?.some(deck))
                        }
                    }
                    Stepper(String(localized: "At least \(card.minPlayers) players"), value: $card.minPlayers, in: 1...12)
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
                        let trimmedHook = hook.trimmingCharacters(in: .whitespaces)
                        let trimmedPuff = puff.trimmingCharacters(in: .whitespaces)
                        saved.hook = trimmedHook == (original.displayHook ?? "") ? original.hook : (trimmedHook.isEmpty ? nil : trimmedHook)
                        saved.puff = trimmedPuff == (original.displayPuff ?? "") ? original.puff : (trimmedPuff.isEmpty ? nil : trimmedPuff)
                        onSave(saved)
                        dismiss()
                    }
                    .disabled(card.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

extension PromptDeck {
    var label: String {
        switch self {
        case .letters: String(localized: "A letter and a category")
        case .neverHaveIEver: String(localized: "Never have I ever")
        case .wouldYouRather: String(localized: "Would you rather")
        case .mostLikely: String(localized: "Most likely to")
        case .hotSeat: String(localized: "Hot seat questions")
        case .debate: String(localized: "Debate statements")
        case .conspiracy: String(localized: "Conspiracy topics")
        case .story: String(localized: "Story openings")
        case .explain: String(localized: "Things to explain")
        case .actItOut: String(localized: "Scenes to act out")
        case .categories: String(localized: "Categories")
        case .rhyme: String(localized: "Words to rhyme")
        case .straightFace: String(localized: "Lines to say")
        case .impressions: String(localized: "Impressions")
        case .songs: String(localized: "Songs to hum")
        case .island: String(localized: "Pick-three scenarios")
        case .bingo: String(localized: "Bingo things")
        case .tableRule: String(localized: "Table rules")
        }
    }
}
