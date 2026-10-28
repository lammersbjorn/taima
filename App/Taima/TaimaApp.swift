import CoreSpotlight
import UserNotifications
import SwiftUI
import TaimaCore

@main
struct TaimaApp: App {
    @State private var model = AppModel()

    init() {
        UNUserNotificationCenter.current().delegate = NotificationPresenter.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modifier(PrivacyShield())
                // Outermost, so the privacy shield can read the model too.
                .environment(model)
                .onOpenURL { model.handle($0) }
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    if let id = (activity.userInfo?[CSSearchableItemActivityIdentifier] as? String).flatMap(UUID.init(uuidString:)) {
                        model.destination = .bag(id)
                    }
                }
                #if DEBUG
                .task { await model.debugImport() }
                #endif
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = AppTab.collection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var presentedDraft: BagDraft?
    @State private var linkedBag: UUID?
    /// A link that arrived while another sheet was up.
    @State private var pendingLink: UUID?
    @AppStorage("onboarding.done") private var onboardingDone = false
    @AppStorage("highlights.seenThrough") private var seenThrough = 0
    @State private var showingOnboarding = false
    @State private var owedHighlights: [ReleaseHighlights] = []
    #if DEBUG
    private let debugTab = ProcessInfo.processInfo.environment["TAIMA_TAB"]
    #endif

    enum AppTab: Hashable { case stash, collection, stats, tools, search }

    var body: some View {
        overlays(lifecycle(presentations(tabs)))
    }

    private var tabs: some View {
        TabView(selection: $tab) {
            Tab("Stash", systemImage: "bag.fill", value: .stash) {
                StashView()
            }
            Tab("Collection", systemImage: "square.stack.3d.up.fill", value: .collection) {
                CollectionView()
            }
            Tab("Stats", systemImage: "chart.bar.xaxis", value: .stats) {
                StatsView()
            }
            Tab("Tools", systemImage: "wrench.and.screwdriver.fill", value: .tools) {
                ToolsView()
            }
            Tab(value: .search, role: .search) {
                SearchView()
            }
        }
    }

    private func presentations(_ content: some View) -> some View {
        @Bindable var model = model
        return content
        .modifier(CurrentBagAccessory(onStash: tab == .stash))
        .sheet(item: $presentedDraft, onDismiss: { presentNextDraft(); flushLink() }) { draft in
            BagEditorView(draft: draft)
                .interactiveDismissDisabled()
        }
        .onChange(of: model.drafts.first?.id, initial: true) { _, first in
            if let presented = presentedDraft, presented.id != first {
                presentedDraft = nil  // finished; onDismiss shows the next one
            } else {
                presentNextDraft()
            }
        }
        .onChange(of: model.scanProgress == nil) { presentNextDraft() }
        .onChange(of: model.isLocked) { _, locked in
            // A link that arrived behind the lock opens once unlocked.
            if !locked { openDestination() }
        }
        .onChange(of: model.destination) { openDestination() }
        .sheet(isPresented: $model.showingSettings, onDismiss: { presentNextDraft(); flushLink() }) { SettingsView() }
        .sheet(item: $model.pendingSample, onDismiss: presentNextDraft) { pending in
            SampleShareSheet(sample: pending.sample)
        }
        .sheet(item: $model.noteTarget) { bag in
            AddNoteSheet(bag: bag).presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $model.showingEntryReview, onDismiss: { presentNextDraft(); flushLink() }) { EntryReviewView() }
        .fullScreenCover(isPresented: $model.showingChecker, onDismiss: flushLink) {
            CheckBagView()
        }
        .sheet(item: $linkedBag, onDismiss: presentNextDraft) { id in
            NavigationStack {
                BagDetailView(id: id)
                    .navigationDestination(for: UUID.self) { BagDetailView(id: $0) }
                    .navigationDestination(for: StrainInfo.self) { StrainInfoView(strain: $0) }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close", systemImage: "xmark") { linkedBag = nil }
                        }
                    }
            }
        }
        .fullScreenCover(isPresented: $showingOnboarding, onDismiss: {
            onboardingDone = true
            seenThrough = ReleaseHighlights.currentBuild
            presentNextDraft()
            flushLink()
        }) {
            OnboardingView()
        }
        .sheet(isPresented: Binding(get: { !owedHighlights.isEmpty }, set: { if !$0 { owedHighlights = [] } }), onDismiss: {
            seenThrough = ReleaseHighlights.currentBuild
            presentNextDraft()
            flushLink()
            // An update that reads labels better asks to re-read older bags.
            if model.reviewIsOwed {
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    model.showingEntryReview = true
                }
            }
        }) {
            WhatsNewView(releases: owedHighlights)
        }
    }

    private func lifecycle(_ content: some View) -> some View {
        content
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.environment["TAIMA_SKIP_INTRO"] == "1" { return }
            #endif
            // A first launch gets the introduction; an update gets its highlights.
            if !onboardingDone {
                if model.bags.isEmpty {
                    showingOnboarding = true
                } else {
                    onboardingDone = true
                    owedHighlights = ReleaseHighlights.owed(seenThrough: seenThrough)
                }
            } else {
                owedHighlights = ReleaseHighlights.owed(seenThrough: seenThrough)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.reload()
                Task { await model.updates.checkIfDue() }
            }
            if phase == .background { AutoBackup.runIfDue(model) }
        }
        .onChange(of: model.resetCount) {
            // A full reset starts over like a fresh install.
            presentedDraft = nil
            linkedBag = nil
            pendingLink = nil
            owedHighlights = []
            tab = .collection
            onboardingDone = false
            seenThrough = ReleaseHighlights.currentBuild
            showingOnboarding = true
        }
    }

    private func overlays(_ content: some View) -> some View {
        content
        .overlay {
            if let progress = model.scanProgress {
                ScanProgressView(done: progress.done, total: progress.total)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .top) {
            if let milestone = model.newMilestone {
                MilestoneToast(milestone: milestone)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .scale(scale: 0.8)).combined(with: .opacity))
            } else if let offer = model.undoOffer {
                UndoToast(message: offer.message) { model.undoLast() }
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .id(offer.id)
            } else if let name = model.savedName {
                SavedToast(name: name)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.5, bounce: 0.35), value: model.newMilestone?.id)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.4), value: model.savedName)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.4), value: model.undoOffer?.id)
        .animation(.default, value: model.scanProgress?.done)
        .sensoryFeedback(.success, trigger: model.savedName) { _, new in new != nil }
        #if DEBUG
        .sheet(item: Binding(get: { model.debugStrain }, set: { model.debugStrain = $0 })) { strain in
            NavigationStack {
                StrainInfoView(strain: strain)
                    .navigationDestination(for: StrainInfo.self) { StrainInfoView(strain: $0) }
                    .navigationDestination(for: UUID.self) { BagDetailView(id: $0) }
            }
        }
        .onAppear {
            switch debugTab {
            case "stats": tab = .stats
            case "stash": tab = .stash
            case "tools": tab = .tools
            case "collection": tab = .collection
            case "search": tab = .search
            default: break
            }
            if ProcessInfo.processInfo.environment["TAIMA_SKIP_INTRO"] == "1" {
                onboardingDone = true
                seenThrough = ReleaseHighlights.currentBuild
            }
        }
        #endif
        .alert("Something went wrong", isPresented: Binding(
            get: { model.problem != nil && presentedDraft == nil },
            set: { if !$0 { model.problem = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.problem ?? "")
        }
    }

    /// Waits until reading has finished, so the sheet never fights the
    /// progress overlay or a closing photo picker.
    /// Opens a link from a widget, Spotlight or a shortcut, unless locked.
    private func openDestination() {
        guard let destination = model.destination, !model.isLocked else { return }
        model.destination = nil
        switch destination {
        case .stash: tab = .stash
        case .pick:
            model.showingSettings = false
            tab = .collection
            model.pendingPhotoPick = true
        case .scan:
            model.showingSettings = false
            tab = .collection
            model.pendingCameraScan = true
        case .note(let id):
            if let bag = model.bag(id: id) { model.noteTarget = bag }
        case .bag(let id):
            guard model.bag(id: id) != nil else { break }
            if presentedDraft != nil || showingOnboarding || !owedHighlights.isEmpty || !model.drafts.isEmpty || model.showingChecker || model.showingSettings {
                pendingLink = id
            } else {
                linkedBag = id
            }
        }
    }

    private func flushLink() {
        guard let id = pendingLink, presentedDraft == nil, model.drafts.isEmpty, !showingOnboarding, owedHighlights.isEmpty, !model.showingChecker, !model.showingSettings else { return }
        pendingLink = nil
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            linkedBag = id
        }
    }

    private func presentNextDraft() {
        guard presentedDraft == nil, linkedBag == nil, !showingOnboarding, owedHighlights.isEmpty, !model.showingSettings, model.pendingSample == nil,
              model.scanProgress == nil, let next = model.drafts.first else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            if presentedDraft == nil, model.scanProgress == nil, let first = model.drafts.first, first.id == next.id {
                presentedDraft = first
            }
        }
    }
}

extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}

struct ScanProgressView: View {
    let done: Int
    let total: Int

    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 14) {
                Mascot(size: 72)
                ProgressView(value: Double(done), total: Double(max(total, 1)))
                    .tint(Theme.leafMid)
                    .frame(width: 160)
                Text(total > 1 ? "Reading label \(min(done + 1, total)) of \(total)" : "Reading label")
                    .font(.headline)
                    .contentTransition(.numericText())
                Text("On this iPhone")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(28)
            .glassEffect(.regular, in: .rect(cornerRadius: 28))
        }
        .accessibilityElement(children: .combine)
    }
}

/// The bag in use above the tab bar on every tab, like Music's mini player.
struct CurrentBagAccessory: ViewModifier {
    @Environment(AppModel.self) private var model
    /// Hidden on Stash, which already shows the bag in use.
    var onStash = false

    func body(content: Content) -> some View {
        if #available(iOS 26.1, *) {
            content.tabViewBottomAccessory(isEnabled: model.currentBag != nil && !onStash) {
                if let bag = model.currentBag {
                    CurrentBagBar(bag: bag)
                }
            }
        } else {
            content
        }
    }
}

struct CurrentBagBar: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    let bag: Bag
    @State private var logged = 0

    var body: some View {
        HStack(spacing: 10) {
            BagPhoto(name: bag.mainPhoto)
                .frame(width: 30, height: 30)
                .clipShape(.circle)
            if placement != .inline {
                VStack(alignment: .leading, spacing: 0) {
                    Text(bag.displayName).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Text(bag.remainingLabel + " left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            } else {
                Text(bag.remainingLabel).font(.subheadline.weight(.semibold)).contentTransition(.numericText())
            }
            Spacer(minLength: 4)
            Button {
                withAnimation(.snappy) { _ = model.use(bag.gramsPerUnit ?? 0.25, from: bag) }
                logged += 1
            } label: {
                Label(bag.gramsPerUnit == nil ? QuickAmounts.label(0.25) : "One", systemImage: "minus")
                    .font(.subheadline.weight(.semibold))
            }
            .accessibilityLabel(bag.gramsPerUnit == nil ? "Log \(QuickAmounts.label(0.25))" : "Log one preroll")
        }
        .padding(.horizontal, 12)
        .sensoryFeedback(.impact(weight: .light), trigger: logged)
        .onTapGesture { model.destination = .stash }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Open Stash") { model.destination = .stash }
    }
}

/// Search your collection or the strain library.
struct SearchView: View {
    enum Scope: String, CaseIterable, Identifiable {
        case collection, library
        var id: Self { self }
        var label: String { self == .collection ? "Your bags" : "Strain library" }
    }

    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var scope = Scope.collection

    var body: some View {
        NavigationStack {
            Group {
                if scope == .library {
                    StrainLibraryList(query: query)
                } else {
                    collection
                }
            }
            .navigationTitle("Search")
            .navigationDestination(for: UUID.self) { BagDetailView(id: $0) }
            .navigationDestination(for: StrainInfo.self) { StrainInfoView(strain: $0) }
            .searchable(text: $query, prompt: scope == .library ? "Strain or alias" : "Name, grower or note")
            .safeAreaInset(edge: .top) {
                Picker("Search in", selection: $scope) {
                    ForEach(Scope.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 6)
            }
            .background(GlowBackground())
            .toolbar { ToolbarItem(placement: .topBarTrailing) { SettingsToolbarButton() } }
        }
    }

    private var collection: some View {
        let text = query.trimmingCharacters(in: .whitespaces)
        let results = text.isEmpty ? [] : model.bags.filter { bag in
            [bag.name, bag.producer ?? "", bag.notes, bag.strainType?.label ?? "", bag.form.label, bag.productID ?? "", bag.shop ?? "", bag.shopCity ?? ""]
                .contains { $0.localizedCaseInsensitiveContains(text) }
        }
        return List {
            if text.isEmpty {
                // Something useful before typing: recent bags and the wishlist.
                if !model.bags.isEmpty {
                    Section("Recently added") {
                        ForEach(model.bags.sorted { $0.createdAt > $1.createdAt }.prefix(4)) { bag in
                            NavigationLink(value: bag.id) { BagRow(bag: bag) }
                        }
                    }
                }
                Section {
                    Button {
                        scope = .library
                    } label: {
                        HStack(spacing: 12) {
                            Mascot(size: 44, animated: false)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Explore the strain library").font(.headline).foregroundStyle(.primary)
                                Text(model.wishlist.isEmpty
                                     ? "Lineage, aliases and crosses. Tap the heart on a strain to remember it."
                                     : "\(model.wishlist.count) on your want-to-try list")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } else {
                ForEach(results) { bag in
                    NavigationLink(value: bag.id) { BagRow(bag: bag) }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .overlay {
            if !text.isEmpty && results.isEmpty {
                ContentUnavailableView.search(text: text)
            }
        }
    }
}
