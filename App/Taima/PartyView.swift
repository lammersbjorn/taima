import SwiftUI
import TaimaCore

/// Party games: set up the players and the deck, then play full screen.
/// Nothing here is logged against the stash.
struct RouletteView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("party.settings") private var stored = Data()
    @State private var settings = PartySettings()
    @State private var loaded = false
    @State private var playing: PartyPlayView.Mode?
    @State private var showingPlayers = false
    @State private var showingCustomize = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                playersSection
                rouletteSection
                startSection
                deckSection
                GameLibrary(settings: $settings) { playing = .only($0) }
            }
            .padding()
        }
        .background(GlowBackground())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Customize", systemImage: "slider.horizontal.3") { showingCustomize = true }
            }
        }
        .fullScreenCover(item: $playing) { mode in
            PartyPlayView(mode: mode, settings: $settings)
        }
        .sheet(isPresented: $showingPlayers) { PlayersSheet(settings: $settings) }
        .sheet(isPresented: $showingCustomize) { CustomizeSheet(settings: $settings) }
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

    // MARK: Players

    private var playersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Players").font(.headline)
                Spacer()
                Button(settings.players.isEmpty ? String(localized: "Add") : String(localized: "Edit")) { showingPlayers = true }
                    .font(.subheadline.weight(.semibold))
            }
            if settings.players.isEmpty {
                Button { showingPlayers = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.2.badge.plus")
                            .font(.title3)
                            .foregroundStyle(Theme.leaf)
                        Text("Add who's playing, and the cards use your names.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .glassCard()
                }
                .buttonStyle(.plain)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 14) {
                        ForEach(Array(settings.players.enumerated()), id: \.element.id) { index, player in
                            VStack(spacing: 6) {
                                PlayerAvatar(name: player.name, index: index, size: 56)
                                Text(player.name).font(.caption.weight(.semibold)).lineLimit(1)
                                Text(String(localized: "\(player.points) pts"))
                                    .font(.caption2)
                                    .foregroundStyle(Theme.secondaryText)
                                    .monospacedDigit()
                            }
                            .frame(width: 72)
                            .accessibilityElement(children: .combine)
                        }
                        Button { showingPlayers = true } label: {
                            Image(systemName: "plus")
                                .font(.title3.weight(.semibold))
                                .frame(width: 56, height: 56)
                                .background(Theme.cellRaised, in: .circle)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.leaf)
                        .accessibilityLabel("Add players")
                        .frame(maxHeight: .infinity, alignment: .top)
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    // MARK: Roulette

    /// Spin for any mix of a strain, a way to smoke and a game.
    private var rouletteSection: some View {
        let anyOn = settings.rouletteStrain || settings.rouletteWay || settings.rouletteGame
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Roulette").font(.headline)
                Text("Choose what to spin for.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
            HStack(spacing: 8) {
                rouletteToggle(String(localized: "Strain"), "leaf.fill", isOn: $settings.rouletteStrain)
                rouletteToggle(String(localized: "Way"), "flame.fill", isOn: $settings.rouletteWay)
                rouletteToggle(String(localized: "Game"), "suit.club.fill", isOn: $settings.rouletteGame)
            }
            Button {
                playing = .roulette
            } label: {
                Label("Spin", systemImage: "dice.fill")
                    .font(.title3.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .solidProminent()
            .buttonBorderShape(.capsule)
            .tint(Theme.solid)
            .disabled(!anyOn)
        }
        .glassCard()
    }

    private func rouletteToggle(_ title: String, _ symbol: String, isOn: Binding<Bool>) -> some View {
        Button {
            withAnimation(.snappy) { isOn.wrappedValue.toggle() }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: isOn.wrappedValue ? symbol : "circle.dashed")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isOn.wrappedValue ? Theme.leaf : Theme.secondaryText)
                    .contentTransition(.symbolEffect(.replace))
                Text(title).font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .foregroundStyle(.primary)
            .background { SelectableChipBackground(isOn: isOn.wrappedValue, hue: Theme.leafMid, shape: AnyShape(RoundedRectangle(cornerRadius: 16, style: .continuous))) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isOn.wrappedValue ? String(localized: "On") : String(localized: "Off"))
        .accessibilityAddTraits(isOn.wrappedValue ? .isSelected : [])
    }

    // MARK: Start

    private var startSection: some View {
        VStack(spacing: 8) {
            Button {
                playing = .mixed
            } label: {
                Label("Play the card deck", systemImage: "rectangle.stack.fill")
                    .font(.title3.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .tint(Theme.leaf)
            Text(String(localized: "\(PartyDeck.cardCount) cards: challenges, duels, votes, mini-games and more."))
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Deck

    private var deckSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("In the deck").font(.headline)
            FlowLayout(spacing: 8) {
                ForEach(DeckKind.choosable) { kind in
                    let isOn = settings.deckKindOn(kind)
                    Button {
                        withAnimation(.snappy) { settings.setDeckKind(kind, on: !isOn) }
                    } label: {
                        Label(kind.label, systemImage: kind.symbol)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .foregroundStyle(.primary)
                            .background { SelectableChipBackground(isOn: isOn, hue: kind.hue, shape: AnyShape(Capsule())) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            Toggle(isOn: Binding(get: { settings.legendaryChance > 0 }, set: { settings.legendaryChance = $0 ? 1.0 / 15 : 0 })) {
                Label("Rare legendary cards", systemImage: "sparkles")
            }
            .tint(Theme.solid)
            .glassCard(padding: 14)
        }
    }
}

/// A round initial disc for a player, in a colour of its own.
struct PlayerAvatar: View {
    let name: String
    let index: Int
    var size: CGFloat = 44

    static let hues: [Color] = [Theme.solid, .indigo, .orange, .pink, .teal, .purple, .brown, .blue]

    var body: some View {
        Text(String(name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased())
            .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Self.hues[index % Self.hues.count].gradient, in: .circle)
            .accessibilityHidden(true)
    }
}

// MARK: - Library

/// Every mini-game, to play on its own.
private struct GameLibrary: View {
    @Binding var settings: PartySettings
    let play: (RuleCard) -> Void

    var body: some View {
        let cards = settings.cards.filter { $0.enabled && $0.kind == .game }
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Play one game").font(.headline)
                Text("Pick a game and keep playing it, card after card.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 158), spacing: 12, alignment: .top)], spacing: 12) {
                ForEach(cards) { card in
                    Button { play(card) } label: { GameTile(card: card) }
                        .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct GameTile: View {
    let card: RuleCard

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GameIcon(card: card, size: 38)
            Text(card.displayTitle).font(.headline).foregroundStyle(.primary).lineLimit(2)
            if let hook = card.displayHook {
                Text(hook).font(.caption).foregroundStyle(Theme.secondaryText).lineLimit(2)
            }
            Spacer(minLength: 0)
            Text(String(localized: "\(card.minPlayers)+ players"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .glassCard(padding: 14)
        .overlay {
            if card.legendary {
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .strokeBorder(GameStyle.gold.opacity(0.7), lineWidth: 1.5)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Deck kinds

extension DeckKind {
    var label: String {
        switch self {
        case .challenge: String(localized: "Challenges")
        case .duel: String(localized: "Duels")
        case .vote: String(localized: "Votes")
        case .everyone: String(localized: "Hands up")
        case .question: String(localized: "Questions")
        case .dilemma: String(localized: "Dilemmas")
        case .quickfire: String(localized: "Quick-fire")
        case .act: String(localized: "Charades")
        case .debate: String(localized: "Debates")
        case .rule, .ruleEnd: String(localized: "Table rules")
        case .minigame: String(localized: "Mini-games")
        case .smoke: String(localized: "Smoke rounds")
        case .legendary: String(localized: "Legendary")
        }
    }

    /// The small label on a card.
    var cardLabel: String {
        switch self {
        case .challenge: String(localized: "Challenge")
        case .duel: String(localized: "Duel")
        case .vote: String(localized: "Vote")
        case .everyone: String(localized: "Hands up")
        case .question: String(localized: "Question")
        case .dilemma: String(localized: "Dilemma")
        case .quickfire: String(localized: "Quick-fire")
        case .act: String(localized: "Charades")
        case .debate: String(localized: "Debate")
        case .rule: String(localized: "New table rule")
        case .ruleEnd: String(localized: "Rule over")
        case .minigame: String(localized: "Mini-game")
        case .smoke: String(localized: "Smoke round")
        case .legendary: String(localized: "Legendary")
        }
    }

    var symbol: String {
        switch self {
        case .challenge: "bolt.fill"
        case .duel: "figure.fencing"
        case .vote: "hand.point.up.left.fill"
        case .everyone: "hand.raised.fill"
        case .question: "bubble.left.fill"
        case .dilemma: "arrow.left.arrow.right"
        case .quickfire: "timer"
        case .act: "theatermasks.fill"
        case .debate: "megaphone.fill"
        case .rule, .ruleEnd: "scroll.fill"
        case .minigame: "gamecontroller.fill"
        case .smoke: "leaf.fill"
        case .legendary: "sparkles"
        }
    }

    /// Deep enough for white text at 5:1 or more.
    var hue: Color {
        switch self {
        case .challenge: Color(red: 0.71, green: 0.27, blue: 0.11)
        case .duel: Color(red: 0.64, green: 0.10, blue: 0.23)
        case .vote: Color(red: 0.24, green: 0.21, blue: 0.65)
        case .everyone: Color(red: 0.05, green: 0.42, blue: 0.40)
        case .question: Color(red: 0.43, green: 0.16, blue: 0.53)
        case .dilemma: Color(red: 0.12, green: 0.37, blue: 0.66)
        case .quickfire: Color(red: 0.48, green: 0.32, blue: 0.0)
        case .act: Color(red: 0.54, green: 0.12, blue: 0.43)
        case .debate: Color(red: 0.48, green: 0.14, blue: 0.09)
        case .rule, .ruleEnd: Color(red: 0.18, green: 0.24, blue: 0.32)
        case .minigame: Theme.solid
        case .smoke: Color(red: 0.08, green: 0.33, blue: 0.18)
        case .legendary: Color(red: 0.10, green: 0.08, blue: 0.02)
        }
    }

    /// One line under the card that says how it's played.
    var footer: String? {
        switch self {
        case .vote: String(localized: "Point on three. Most fingers explains themselves.")
        case .everyone: String(localized: "One of you tells the story.")
        case .question: String(localized: "Answer, or pass it on.")
        case .dilemma: String(localized: "On three, point left or right. The smaller side explains.")
        case .quickfire: String(localized: "Freeze or repeat and you're out. The last one standing picks who smokes next.")
        case .debate: String(localized: "45 seconds each. The group votes.")
        case .rule: String(localized: "Break it? Compliment the person on your left. Lasts five cards.")
        case .act: String(localized: "The first right guess gets the next hit.")
        default: nil
        }
    }

    /// Cards with a winner to score.
    var scores: Bool { [.challenge, .duel, .debate, .quickfire, .act, .minigame].contains(self) }
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

// MARK: - Playing

/// The deck, full screen: one bold card at a time. Tap Next or swipe to go on.
struct PartyPlayView: View {
    enum Mode: Hashable, Identifiable {
        case mixed
        case roulette
        case only(RuleCard)
        var id: String {
            switch self {
            case .mixed: "mixed"
            case .roulette: "roulette"
            case .only(let card): card.id
            }
        }
    }

    let mode: Mode
    @Binding var settings: PartySettings
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var state = DeckState()
    @State private var card: DealtCard?
    @State private var roulette: RouletteSpin?
    @State private var preview: (bag: Bag?, way: SmokeWay?)?
    @State private var revealing = false
    @State private var rules: RuleCard?
    @State private var scored: UUID?

    var body: some View {
        let kind = isRoulette ? (roulette?.game?.kind == .legendary ? .legendary : .smoke) : (card?.kind ?? .minigame)
        ZStack {
            kind.hue.ignoresSafeArea()
                .animation(.easeInOut(duration: 0.35), value: kind)
            VStack(spacing: 0) {
                topBar(kind)
                if let rule = state.rule, card?.kind != .rule {
                    ruleBanner(rule)
                }
                Spacer(minLength: 12)
                if isRoulette {
                    if let preview {
                        RouletteSpinning(bag: preview.bag, way: preview.way)
                    } else if let roulette {
                        RouletteContent(spin: roulette, settings: settings, showRules: { rules = $0 })
                            .id(roulette.id)
                            .transition(reduceMotion ? .opacity : .scale(scale: 0.92).combined(with: .opacity))
                    }
                } else if let card {
                    PartyCardContent(card: card, settings: settings, showRules: { rules = $0 })
                        .id(card.id)
                        .transition(reduceMotion ? .opacity : .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)))
                }
                Spacer(minLength: 12)
                bottomBar(kind)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            if revealing {
                LegendaryReveal().transition(.opacity).allowsHitTesting(false)
            }
        }
        .contentShape(.rect)
        .gesture(DragGesture(minimumDistance: 40).onEnded { value in
            if value.translation.width < -60 { next() }
        })
        .sheet(item: $rules) { card in RulesSheet(card: card) }
        .sensoryFeedback(.selection, trigger: card?.id)
        .onAppear { if card == nil && roulette == nil { next() } }
        .statusBarHidden()
    }

    private func topBar(_ kind: DeckKind) -> some View {
        HStack {
            Button("Close", systemImage: "xmark") { dismiss() }
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .controlSize(.large)
            Spacer()
            Label(isRoulette ? String(localized: "Roulette") : kind.cardLabel, systemImage: isRoulette ? "dice.fill" : kind.symbol)
                .font(.subheadline.weight(.bold))
                .textCase(.uppercase)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.white.opacity(0.16), in: .capsule)
                .foregroundStyle(kind == .legendary ? GameStyle.gold : .white)
            Spacer()
            Text("\(state.dealt)")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel(String(localized: "Card \(state.dealt)"))
        }
        .padding(.top, 8)
    }

    private func ruleBanner(_ rule: DeckState.ActiveRule) -> some View {
        Label {
            Text(rule.text).font(.footnote.weight(.semibold)).lineLimit(2)
        } icon: {
            Image(systemName: "scroll.fill")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.14), in: .rect(cornerRadius: 16))
        .padding(.top, 10)
        .accessibilityLabel(String(localized: "Table rule: \(rule.text)"))
    }

    @ViewBuilder private func bottomBar(_ kind: DeckKind) -> some View {
        VStack(spacing: 14) {
            if (isRoulette ? roulette?.game?.kind.scores == true : kind.scores), preview == nil, settings.players.count >= 2 {
                VStack(spacing: 6) {
                    Text("Who won? Tap for a point.").font(.caption.weight(.semibold)).opacity(0.85)
                    ScrollView(.horizontal) {
                        HStack(spacing: 12) {
                            ForEach(Array(settings.players.enumerated()), id: \.element.id) { index, player in
                                Button { award(player.id) } label: {
                                    VStack(spacing: 4) {
                                        PlayerAvatar(name: player.name, index: index, size: 44)
                                            .overlay { if scored == player.id { Circle().stroke(.white, lineWidth: 3) } }
                                            .scaleEffect(scored == player.id ? 1.12 : 1)
                                        Text("\(player.points)").font(.caption2.weight(.bold)).monospacedDigit()
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(String(localized: "Point for \(player.name), now \(player.points)"))
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            Button { next() } label: {
                Text(isRoulette ? String(localized: "Spin again") : String(localized: "Next card"))
                    .font(.title3.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .foregroundStyle(kind.hue)
                    .background(.white, in: .capsule)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Or swipe left")
        }
        .padding(.bottom, 12)
    }

    private var isRoulette: Bool { if case .roulette = mode { true } else { false } }

    /// A short spin through the stash before the result lands.
    private func spinRoulette() {
        guard preview == nil else { return }
        let pool = settings.onlyStash ? model.bags.filter { $0.stock != .empty } : model.bags
        let ways = settings.ways.filter(\.enabled)
        let result = PartyDeck.roulette(settings, bags: model.bags, state: &state)
        let legendary = result.game?.kind == .legendary
        settings.spinsSinceLegendary = legendary ? 0 : settings.spinsSinceLegendary + 1
        Task {
            if !reduceMotion && (settings.rouletteStrain || settings.rouletteWay) {
                for step in 0..<9 {
                    withAnimation(.spring(duration: 0.18)) {
                        preview = (settings.rouletteStrain ? pool.randomElement() : nil, settings.rouletteWay ? ways.randomElement() : nil)
                    }
                    try? await Task.sleep(for: .milliseconds(55 + step * 20))
                }
            }
            if legendary {
                withAnimation(.easeOut(duration: 0.2)) { revealing = true }
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 400 : 1000))
            }
            withAnimation(.spring(duration: 0.45, bounce: 0.3)) {
                preview = nil
                roulette = result
                revealing = false
            }
        }
    }

    private func next() {
        scored = nil
        if isRoulette {
            spinRoulette()
            return
        }
        var dealt: DealtCard
        switch mode {
        case .mixed, .roulette: dealt = PartyDeck.next(settings, bags: model.bags, state: &state)
        case .only(let game): dealt = PartyDeck.next(only: game, settings, state: &state)
        }
        let legendary = dealt.kind == .legendary
        settings.spinsSinceLegendary = legendary ? 0 : settings.spinsSinceLegendary + 1
        if legendary, case .mixed = mode {
            withAnimation(.easeOut(duration: 0.2)) { revealing = true }
            Task {
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 400 : 1100))
                withAnimation(.spring(duration: 0.5, bounce: 0.3)) {
                    card = dealt
                    revealing = false
                }
            }
        } else {
            withAnimation(.spring(duration: 0.45, bounce: 0.2)) { card = dealt }
        }
    }

    private func award(_ id: UUID) {
        guard scored != id, let index = settings.players.firstIndex(where: { $0.id == id }) else { return }
        let legendary = (isRoulette ? roulette?.game?.kind : card?.kind) == .legendary
        withAnimation(.snappy) {
            if let previous = scored, let old = settings.players.firstIndex(where: { $0.id == previous }) {
                settings.players[old].points -= legendary ? 3 : 1
            }
            settings.players[index].points += legendary ? 3 : 1
            if legendary { settings.players[index].legendaries += 1 }
            scored = id
        }
    }
}

/// What a card shows, by kind.
private struct PartyCardContent: View {
    @Environment(AppModel.self) private var model
    let card: DealtCard
    let settings: PartySettings
    let showRules: (RuleCard) -> Void
    var compact = false
    @State private var dealt: PartySpin?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            switch card.kind {
            case .smoke: smoke
            case .minigame, .legendary: game
            default: prompt
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // A written card: the text is the hero, names stand out.
    private var prompt: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(highlighted(card.text, names: card.names))
                .font(.system(compact ? .title2 : .largeTitle, design: .rounded, weight: .bold))
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
            if let secret = card.secret {
                SecretPeek(text: secret)
            }
            if let footer = card.kind.footer {
                Text(footer).font(.headline).opacity(0.85)
            }
            if let seconds = card.seconds {
                CardTimer(seconds: seconds)
            }
        }
    }

    // A mini-game or legendary: its name, what it dealt, the rules a tap away.
    @ViewBuilder private var game: some View {
        if let game = card.game {
            let spin = dealt ?? card.spin ?? PartySpin()
            VStack(alignment: .leading, spacing: 16) {
                if let name = card.names.first {
                    Text(String(localized: "\(name), you start")).font(.headline).opacity(0.85)
                }
                Text(game.displayTitle)
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .foregroundStyle(card.kind == .legendary ? GameStyle.gold : .white)
                if let hook = game.displayHook {
                    Text(hook).font(.title3.weight(.semibold)).opacity(0.9)
                }
                if game.dealsCombo, spin.combo.count == 2 {
                    HStack(spacing: 10) {
                        comboPart(spin.combo[0])
                        Image(systemName: "plus").font(.title3.weight(.bold))
                        comboPart(spin.combo[1])
                    }
                }
                if game.deck == .letters, let letter = spin.letter {
                    HStack(alignment: .center, spacing: 18) {
                        Text(String(letter))
                            .font(.system(size: 88, weight: .heavy, design: .rounded))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Category").font(.caption.weight(.semibold)).opacity(0.8)
                            Text(spin.category.map(PartyText.display) ?? "").font(.title2.weight(.bold))
                        }
                    }
                } else if !spin.prompts.isEmpty {
                    if game.deck?.isSecret == true {
                        SecretPeek(text: spin.prompts.joined(separator: "\n"))
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(spin.prompts.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(spin.prompts.count > 1 ? .title3.weight(.semibold) : .title2.weight(.bold))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.14), in: .rect(cornerRadius: 22))
                    }
                }
                HStack(spacing: 10) {
                    Button("How to play", systemImage: "questionmark.circle") { showRules(game) }
                        .buttonStyle(.glass)
                    if let deck = game.deck {
                        Button(deck == .letters ? String(localized: "New letter") : String(localized: "Another"), systemImage: "arrow.triangle.2.circlepath") {
                            var next = spin
                            PartyEngine.deal(deck, settings: settings, into: &next)
                            withAnimation(.snappy) { dealt = next }
                        }
                        .buttonStyle(.glass)
                    }
                }
                if let puff = game.displayPuff {
                    Label(String(localized: "Puff: \(puff)"), systemImage: "leaf.fill")
                        .font(.subheadline.weight(.semibold))
                        .opacity(0.9)
                }
            }
        }
    }

    // A smoke round: the strain and the way, from the stash.
    @ViewBuilder private var smoke: some View {
        let bag = card.spin?.bagID.flatMap(model.bag(id:))
        VStack(alignment: .leading, spacing: 18) {
            Text(String(localized: "\(card.text), you roll this one."))
                .font(.system(.title, design: .rounded, weight: .bold))
            if let bag {
                HStack(spacing: 16) {
                    BagPhoto(name: bag.mainPhoto)
                        .frame(width: 96, height: 96)
                        .clipShape(.rect(cornerRadius: 20))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(bag.displayName).font(.title3.weight(.bold)).lineLimit(2)
                        if let thc = bag.thc { Text("THC \(thc.label)").font(.subheadline).opacity(0.85) }
                    }
                }
            }
            if let way = card.spin?.way {
                Label(way.displayName, systemImage: way.symbol)
                    .font(.title2.weight(.bold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(.white.opacity(0.16), in: .capsule)
            }
        }
    }

    private func comboPart(_ way: SmokeWay) -> some View {
        Label(way.displayName, systemImage: way.symbol)
            .font(.headline)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(GameStyle.gold.opacity(0.3), in: .capsule)
    }

    /// Names in bold with a warm highlight, so you see at once who's up.
    private func highlighted(_ text: String, names: [String]) -> AttributedString {
        var result = AttributedString(text)
        for name in names where !name.isEmpty {
            var search = result.startIndex..<result.endIndex
            while let range = result[search].range(of: name) {
                result[range].foregroundColor = Color(red: 1, green: 0.86, blue: 0.5)
                search = range.upperBound..<result.endIndex
            }
        }
        return result
    }
}

/// The quick flicker while the roulette spins.
private struct RouletteSpinning: View {
    let bag: Bag?
    let way: SmokeWay?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let bag {
                HStack(spacing: 16) {
                    BagPhoto(name: bag.mainPhoto)
                        .frame(width: 96, height: 96)
                        .clipShape(.rect(cornerRadius: 20))
                    Text(bag.displayName).font(.title2.weight(.bold)).lineLimit(2)
                }
            }
            if let way {
                Label(way.displayName, systemImage: way.symbol)
                    .font(.title2.weight(.bold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(.white.opacity(0.16), in: .capsule)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(0.75)
        .accessibilityHidden(true)
    }
}

/// A roulette result: who's up, then only what was spun.
private struct RouletteContent: View {
    @Environment(AppModel.self) private var model
    let spin: RouletteSpin
    let settings: PartySettings
    let showRules: (RuleCard) -> Void

    var body: some View {
        let bag = spin.bagID.flatMap(model.bag(id:))
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let name = spin.playerName {
                    Text(String(localized: "\(name), you're up"))
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(Color(red: 1, green: 0.86, blue: 0.5))
                }
                if let bag {
                    HStack(spacing: 16) {
                        BagPhoto(name: bag.mainPhoto)
                            .frame(width: 96, height: 96)
                            .clipShape(.rect(cornerRadius: 20))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(bag.displayName).font(.title2.weight(.bold)).lineLimit(2)
                            if let thc = bag.thc { Text("THC \(thc.label)").font(.subheadline).opacity(0.85) }
                        }
                    }
                } else if settings.rouletteStrain {
                    Text("Nothing in your stash to spin.").font(.headline).opacity(0.85)
                }
                if let way = spin.way {
                    Label(way.displayName, systemImage: way.symbol)
                        .font(.title2.weight(.bold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(.white.opacity(0.16), in: .capsule)
                }
                if let game = spin.game {
                    VStack(alignment: .leading, spacing: 14) {
                        Label(game.kind.cardLabel, systemImage: game.kind.symbol)
                            .font(.caption.weight(.heavy))
                            .textCase(.uppercase)
                            .opacity(0.9)
                        PartyCardContent(card: game, settings: settings, showRules: showRules, compact: true)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(game.kind.hue, in: .rect(cornerRadius: 24))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.18), lineWidth: 1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
    }
}

/// Hidden until held: only the named player should see it.
private struct SecretPeek: View {
    let text: String
    @State private var showing = false

    var body: some View {
        Text(showing ? text : String(localized: "Hold to peek, only you"))
            .font(showing ? .title2.weight(.bold) : .headline)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            .padding(.leading, 18)
            .padding(.trailing, showing ? 18 : 52)
            .background(.white.opacity(showing ? 0.22 : 0.12), in: .rect(cornerRadius: 22))
            .overlay(alignment: .trailing) {
                if !showing { Image(systemName: "eye.slash.fill").padding(.trailing, 18).opacity(0.8) }
            }
            .onLongPressGesture(minimumDuration: 0.05, perform: {}, onPressingChanged: { pressing in
                withAnimation(.snappy(duration: 0.15)) { showing = pressing }
            })
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(String(localized: "Secret. Double-tap and hold to peek."))
            .accessibilityAction { showing.toggle() }
    }
}

/// A countdown for timed cards: tap to start.
private struct CardTimer: View {
    let seconds: Int
    @State private var endsAt: Date?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let left = endsAt.map { max(0, $0.timeIntervalSince(context.date)) }
            Button {
                endsAt = endsAt == nil ? Date.now.addingTimeInterval(TimeInterval(seconds)) : nil
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().stroke(.white.opacity(0.25), lineWidth: 5)
                        Circle()
                            .trim(from: 0, to: left.map { $0 / Double(seconds) } ?? 1)
                            .stroke(.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 40, height: 40)
                    Text(left.map { $0 > 0 ? "\(Int($0.rounded(.up)))" : String(localized: "Time!") } ?? String(localized: "Start \(seconds)s timer"))
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.white.opacity(0.14), in: .capsule)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.warning, trigger: left.map { $0 == 0 } ?? false) { _, done in done }
        }
    }
}

/// How to play a mini-game.
private struct RulesSheet: View {
    @Environment(\.dismiss) private var dismiss
    let card: RuleCard

    var body: some View {
        NavigationStack {
            List {
                if let hook = card.displayHook {
                    Text(hook).font(.headline)
                }
                Section {
                    ForEach(Array(card.displaySteps.enumerated()), id: \.offset) { index, step in
                        Label {
                            Text(step)
                        } icon: {
                            Text("\(index + 1)").font(.subheadline.weight(.bold)).monospacedDigit()
                        }
                    }
                }
                if let puff = card.displayPuff {
                    Section { Label(String(localized: "Puff: \(puff)"), systemImage: "leaf.fill") } footer: { Text("Passing is always fine.") }
                }
            }
            .navigationTitle(card.displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done", systemImage: "checkmark") { dismiss() } } }
        }
        .presentationDetents([.medium, .large]).taimaSheet()
    }
}

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
                        TextField("Add a way", text: $newWay)
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
                                            if card.intense { Label("Intense", systemImage: "exclamationmark.circle").font(.caption.weight(.semibold)).foregroundStyle(.orange) }
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
