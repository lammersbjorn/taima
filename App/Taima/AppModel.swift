import ActivityKit
import CoreSpotlight
import UserNotifications
import Observation
import WidgetKit
import PhotosUI
import SwiftUI
import TaimaCore

/// A bag that is being added or edited, with what the label scan filled in.
struct BagDraft: Identifiable {
    var bag: Bag
    var isNew: Bool
    var detected: Set<LabelField> = []
    var producerKeys: [String] = []
    /// The bag as it was when editing began, to tell the person's changes
    /// from inventory logged meanwhile.
    var original: Bag?
    /// What the label reader produced, to learn from the person's fixes.
    var originalReading: LabelReading?
    /// Read values the reader is unsure of; they ask for a check.
    var doubtful: Set<LabelField> = []
    var id: UUID { bag.id }
}

enum BagSort: String, CaseIterable, Identifiable {
    case newest, oldest, strongest, heaviest, name

    var id: String { rawValue }

    var label: String {
        switch self {
        case .newest: String(localized: "Newest first")
        case .oldest: String(localized: "Oldest first")
        case .strongest: String(localized: "Highest THC")
        case .heaviest: String(localized: "Heaviest")
        case .name: String(localized: "Name")
        }
    }
}

@Observable
final class AppModel {
    /// For App Intents that run in the app's process.
    static weak var shared: AppModel?

    private(set) var bags: [Bag] = [] {
        // Summaries are rebuilt once per change, not on every view update.
        didSet {
            inventory = InventorySummary(bags: bags)
            strains = StrainGroup.group(bags)
        }
    }
    private(set) var inventory = InventorySummary(bags: [])
    private(set) var strains: [StrainGroup] = []
    private(set) var wishlist: [WishItem] = []
    var drafts: [BagDraft] = []
    var problem: String?
    private(set) var scanProgress: (done: Int, total: Int)?
    /// A bag to open, from Spotlight, a widget or a shortcut.
    var openBagID: UUID?
    /// Set by the "Scan a bag" shortcut and control.
    var pendingCameraScan = false
    /// Briefly true after a save, for the confirmation toast.
    private(set) var savedName: String?
    /// A milestone reached by the last change, for a short celebration.
    private(set) var newMilestone: Milestone?
    @ObservationIgnored @AppStorage("milestones.seen") private var seenMilestones = ""
    @ObservationIgnored @AppStorage("milestones.initialized") private var milestonesInitialized = false

    /// Celebrates milestones reached since the last check. The first check
    /// only records what was already earned, so nothing pops up on update.
    private func checkMilestones(silently: Bool = false) {
        let achieved = Milestone.evaluate(bags).filter(\.achieved)
        let seen = Set(seenMilestones.split(separator: ",").map(String.init))
        let fresh = achieved.filter { !seen.contains($0.id) }
        seenMilestones = Array(seen.union(achieved.map(\.id))).sorted().joined(separator: ",")
        guard milestonesInitialized, !silently else {
            milestonesInitialized = true
            return
        }
        guard let first = fresh.first else { return }
        newMilestone = first
        Task {
            try? await Task.sleep(for: .seconds(3))
            if newMilestone?.id == first.id { newMilestone = nil }
        }
    }

    /// The open bag that quick logging and the Live Activity use.
    private(set) var currentBagID: UUID? = SharedContainer.currentBagID

    let photos: PhotoStore
    private let store: BagStore?
    private var inventoryObserver: (any NSObjectProtocol)?

    init() {
        photos = PhotoStore(directory: StorePaths.photos)
        var opened: BagStore?
        do {
            opened = try BagStore(url: StorePaths.database)
            bags = try opened?.allBags() ?? []
            wishlist = (try? opened?.wishlist()) ?? []
        } catch {
            problem = String(localized: "Your collection could not be opened. \(error.localizedDescription)")
        }
        store = opened
        // Observers don't run inside init.
        inventory = InventorySummary(bags: bags)
        strains = StrainGroup.group(bags)
        Self.shared = self
        preloadCatalog()
        updates.onLibraryInstalled = { [weak self] in self?.reloadCatalog() }
        if let unreadable = opened?.unreadableCount, unreadable > 0 {
            problem = String(localized: "\(unreadable) bags were saved by a newer version of Taima and can't be shown. They are kept; install the latest Taima to see them.")
        }
        backfillGrowers()
        checkMilestones()
        tidyCurrent()
        refreshShared()
        syncActivity()
        // Live Activity buttons and Shortcuts write to the database directly.
        inventoryObserver = NotificationCenter.default.addObserver(forName: InventoryActions.changed, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
    }

    func reload() {
        guard let store, let fresh = try? store.allBags() else { return }
        bags = fresh
        tidyCurrent()
        refreshShared()
    }

    /// The current bag must be open; a single open bag becomes current.
    private func tidyCurrent() {
        if let id = currentBagID, bags.first(where: { $0.id == id })?.stock != .open { setCurrent(nil) }
        let open = bags.filter { $0.stock == .open }
        if currentBagID == nil, open.count == 1 { setCurrent(open[0].id) }
    }

    /// Names growers for bags saved before Taima knew them, from the text
    /// already read off their labels.
    private func backfillGrowers() {
        // Names saved before the "C O G" fix read "CQG".
        for bag in bags where bag.name.range(of: #"^C[Q0]G\b"#, options: .regularExpression) != nil {
            update(bag.id) { $0.name = LabelParser.cleanName($0.name) }
        }
        for bag in bags where (bag.producer ?? "").isEmpty {
            let text = [bag.name, bag.recognizedText, bag.backRecognizedText ?? ""].joined(separator: "\n")
            let keys = LabelParser.producerKeys(lineTexts: text.components(separatedBy: "\n"), reading: LabelReading.with(ean: bag.ean, sku: bag.sku))
            let grower = (try? store?.producer(for: keys)) ?? GrowerDirectory.match(keys: keys, text: text)
            if let grower {
                update(bag.id) { $0.producer = grower }
            }
        }
    }

    var currentBag: Bag? { currentBagID.flatMap(bag(id:)) }
    var openBags: [Bag] { bags.filter { $0.stock == .open }.sorted { $0.id == currentBagID && $1.id != currentBagID } }
    var fullBags: [Bag] { bags.filter { $0.stock == .full } }

    // MARK: - Inventory

    /// Saves a change made outside the editor.
    private func update(_ id: UUID, _ change: (inout Bag) -> Void) {
        guard var bag = bag(id: id) else { return }
        change(&bag)
        save(BagDraft(bag: bag, isNew: false), quietly: true)
    }

    func open(_ bag: Bag, makeCurrent: Bool = true) {
        update(bag.id) { $0.open() }
        if makeCurrent { setCurrent(bag.id) }
    }

    /// Takes an amount from a bag and returns what was actually taken.
    @discardableResult
    func use(_ grams: Double, from bag: Bag, details: UsageEntry? = nil) -> Double {
        var taken = 0.0
        let before = InventorySummary(bags: bags)
        update(bag.id) { taken = $0.use(grams, details: details) }
        Notifier.check(before: before, after: InventorySummary(bags: bags))
        if self.bag(id: bag.id)?.stock == .empty, currentBagID == bag.id { setCurrent(nil) }
        syncActivity()
        return taken
    }

    func updateUse(_ entry: UsageEntry, in bag: Bag) {
        update(bag.id) { $0.updateUse(entry) }
    }

    func undoUse(_ entry: UsageEntry, in bag: Bag) {
        let before = self.bag(id: bag.id) ?? bag
        let wasCurrent = currentBagID == bag.id
        update(bag.id) { $0.undoUse(entry.id) }
        syncActivity()
        offerUndo(String(localized: "Removed \(entry.grams.gramsLabel)")) { self.restoreInventory(before, current: wasCurrent) }
    }

    func setStock(_ stock: StockState, for bag: Bag) {
        let before = self.bag(id: bag.id) ?? bag
        let wasCurrent = currentBagID == bag.id
        guard before.stock != stock else { return }
        defer {
            // Full and Empty reset what's left, so the change can be taken back.
            offerUndo(String(localized: "Marked \(stock.label.lowercased())")) { self.restoreInventory(before, current: wasCurrent) }
        }
        update(bag.id) { bag in
            switch stock {
            case .open: bag.open()
            case .full: bag.stock = .full; bag.remainingGrams = bag.grams
            case .empty: bag.stock = .empty; bag.remainingGrams = 0
            }
        }
        if stock != .open, currentBagID == bag.id { setCurrent(nil) }
    }

    func setCurrent(_ id: UUID?) {
        currentBagID = id
        SharedContainer.currentBagID = id
        syncActivity()
        refreshShared()
    }

    /// Keeps exactly one Live Activity, for the current bag.
    func syncActivity() {
        var request: (BagActivityAttributes, BagActivityAttributes.ContentState)?
        if let current = currentBag, current.stock == .open {
            request = (
                BagActivityAttributes(bagID: current.id.uuidString, name: SharedContainer.isDiscreet ? "Bag in use" : current.name, total: current.grams, thc: SharedContainer.isDiscreet ? nil : current.thc?.label, unitGrams: current.gramsPerUnit, unitCount: current.unitCount, discreet: SharedContainer.isDiscreet),
                BagActivityAttributes.ContentState(remaining: current.remaining, usedToday: InventorySummary(bags: bags).usedToday, lastUse: current.lastUse)
            )
        }
        let wanted = request
        // One change at a time, so two quick syncs cannot both start an activity.
        let previous = activityTask
        activityTask = Task.detached {
            await previous?.value
            await Self.applyActivity(wanted)
        }
    }

    @ObservationIgnored private var activityTask: Task<Void, Never>?

    nonisolated private static func applyActivity(_ wanted: (BagActivityAttributes, BagActivityAttributes.ContentState)?) async {
        // A changed name (discreet mode) needs a fresh activity: attributes are fixed.
        for activity in Activity<BagActivityAttributes>.activities where activity.attributes.bagID != wanted?.0.bagID || activity.attributes.name != wanted?.0.name {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        guard let (attributes, state) = wanted else { return }
        if let existing = Activity<BagActivityAttributes>.activities.first(where: { $0.attributes.bagID == attributes.bagID }) {
            await existing.update(ActivityContent(state: state, staleDate: nil))
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            do {
                _ = try Activity.request(attributes: attributes, content: ActivityContent(state: state, staleDate: nil))
            } catch {
                print("Taima: Live Activity request failed: \(error)")
            }
        } else {
            print("Taima: Live Activities are turned off")
        }
    }

    // MARK: - Learning from corrections

    struct PendingSample: Identifiable {
        let id = UUID()
        let sample: LabelSample
    }

    var pendingSample: PendingSample?

    @ObservationIgnored @AppStorage("learning.enabled") var learningEnabled = true
    @ObservationIgnored @AppStorage("learning.share") var sharingSamples = false

    var correctionMemory: CorrectionMemory {
        get {
            UserDefaults.standard.data(forKey: "learning.memory")
                .flatMap { try? JSONDecoder().decode(CorrectionMemory.self, from: $0) } ?? CorrectionMemory()
        }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: "learning.memory") }
    }

    /// After a new bag is saved: remember name fixes on this phone, and, if
    /// the person opted in, offer to share the corrected sample.
    private func learn(from draft: BagDraft, saved bag: Bag) {
        guard let reading = draft.originalReading else { return }
        if learningEnabled {
            var memory = correctionMemory
            memory.learn(read: reading.name, saved: bag.name)
            correctionMemory = memory
        }
        if sharingSamples, let sample = LabelSample.make(reading: reading, saved: bag, appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?") {
            pendingSample = PendingSample(sample: sample)
        }
    }

    // MARK: - Timed notes

    /// The bag the add-note sheet is open for.
    var noteTarget: Bag?

    func addNote(_ text: String, at date: Date, image: UIImage?, to bag: Bag) async {
        let photos = self.photos
        let name = await Task.detached(priority: .userInitiated) {
            image.flatMap { try? photos.save($0) }
        }.value
        // The bag may have been deleted while the photo was saved.
        guard self.bag(id: bag.id) != nil else {
            if let name { photos.delete(name) }
            return
        }
        update(bag.id) { $0.noteLog.append(TimedNote(date: date, text: text, photoName: name)) }
        showSaved(String(localized: "note"))
    }

    func deleteNote(_ note: TimedNote, from bag: Bag) {
        update(bag.id) { $0.noteLog.removeAll { $0.id == note.id } }
        let photos = self.photos
        offerUndo(String(localized: "Deleted note")) {
            self.update(bag.id) { bag in
                bag.noteLog.append(note)
                bag.noteLog.sort { $0.date < $1.date }
            }
        } expire: {
            // The photo goes only once the note can no longer come back.
            if let photo = note.photoName { photos.delete(photo) }
        }
    }

    // MARK: - Undo

    struct UndoOffer: Identifiable {
        let id = UUID()
        let message: String
        let undo: () -> Void
        let expire: () -> Void
    }

    /// The last change that can still be taken back, shown with an Undo button.
    private(set) var undoOffer: UndoOffer?

    func offerUndo(_ message: String, undo: @escaping () -> Void, expire: @escaping () -> Void = {}) {
        undoOffer?.expire()
        let offer = UndoOffer(message: message, undo: undo, expire: expire)
        undoOffer = offer
        Task {
            try? await Task.sleep(for: .seconds(6))
            if undoOffer?.id == offer.id {
                undoOffer = nil
                offer.expire()
            }
        }
    }

    func undoLast() {
        guard let offer = undoOffer else { return }
        undoOffer = nil
        offer.undo()
    }

    /// Puts a bag's stock, logs and notes back as they were.
    private func restoreInventory(_ before: Bag, current wasCurrent: Bool) {
        update(before.id) { bag in
            bag.stockState = before.stockState
            bag.remainingGrams = before.remainingGrams
            bag.usageLog = before.usageLog
            bag.timedNotes = before.timedNotes
        }
        if wasCurrent { setCurrent(before.id) } else { syncActivity() }
    }

    // MARK: - Reviewing older entries

    @ObservationIgnored @AppStorage("entries.reviewedReaderVersion") private var reviewedReaderVersion = 1
    var showingEntryReview = false

    /// Older bags were read by an earlier label reader and may gain fields.
    var reviewIsOwed: Bool {
        !bags.isEmpty && reviewedReaderVersion < EntryReview.readerVersion
            && bags.contains { $0.photoName != nil || $0.backPhotoName != nil }
    }

    func markReviewed() { reviewedReaderVersion = EntryReview.readerVersion }

    /// Re-reads every bag's label photos off the main thread.
    func reviewSuggestions(progress: @escaping (Int, Int) -> Void) async -> [EntryReview.Suggestion] {
        let catalog = strainCatalog
        let photos = self.photos
        let candidates = bags
        var suggestions: [EntryReview.Suggestion] = []
        for (index, bag) in candidates.enumerated() {
            // "Later" closes the sheet and cancels the review.
            if Task.isCancelled { return suggestions }
            progress(index, candidates.count)
            let reading = await Task.detached(priority: .userInitiated) { () -> LabelReading in
                func read(_ name: String?) -> LabelReading? {
                    guard let name, let data = photos.data(named: name) else { return nil }
                    return Self.reread(data)
                }
                let front = read(bag.photoName) ?? LabelReading()
                return read(bag.backPhotoName).map { front.merged(withBack: $0) } ?? front
            }.value
            let match = catalog.match(productName: bag.name)
            let libraryType = match.flatMap { $0.match == .partial ? nil : $0.info.trustedType }
            let keys = reading.producerKeys
            let grower = (try? store?.producer(for: keys)) ?? GrowerDirectory.match(keys: keys, text: bag.name + "\n" + reading.text)
            if let suggestion = EntryReview.suggest(for: bag, reading: reading, libraryType: libraryType, grower: grower) {
                suggestions.append(suggestion)
            }
        }
        progress(candidates.count, candidates.count)
        return suggestions
    }

    func applyReview(_ accepted: [EntryReview.Suggestion]) {
        // Merged like an edit, so anything changed while the review ran is kept.
        for suggestion in accepted where bag(id: suggestion.id) != nil {
            save(BagDraft(bag: suggestion.updated, isNew: false, original: suggestion.original), quietly: true)
        }
        if !accepted.isEmpty { showSaved(String(localized: "\(accepted.count) bags")) }
    }

    // MARK: - Reset

    /// Bumped after a full reset so the interface starts over.
    private(set) var resetCount = 0

    /// Deletes everything Taima stores on this iPhone and returns it to a
    /// first launch: records, photos, settings, shared widget data, the
    /// Spotlight index, reminders, the Live Activity and the alternate icon.
    func eraseEverything() async throws {
        undoOffer = nil
        guard let store else { throw StoreError.sqlite(String(localized: "the collection is not open")) }
        try store.eraseAll()
        photos.deleteAll()

        // Shared with the widget: snapshot, thumbnail and settings.
        for url in [SharedContainer.snapshotURL, SharedContainer.thumbnailURL].compactMap({ $0 }) {
            try? FileManager.default.removeItem(at: url)
        }
        SharedContainer.defaults?.removePersistentDomain(forName: SharedContainer.groupIdentifier)
        if let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
        }

        // Exports wait in tmp until shared; remove any left behind.
        let tmp = FileManager.default.temporaryDirectory
        for file in (try? FileManager.default.contentsOfDirectory(at: tmp, includingPropertiesForKeys: nil)) ?? [] {
            try? FileManager.default.removeItem(at: file)
        }

        // The interface starts over at once; system surfaces follow.
        bags = []
        wishlist = []
        drafts = []
        currentBagID = nil
        destination = nil
        newMilestone = nil
        savedName = nil
        milestonesInitialized = false
        seenMilestones = ""
        resetCount += 1

        WidgetCenter.shared.reloadAllTimelines()
        let notifications = UNUserNotificationCenter.current()
        notifications.removeAllPendingNotificationRequests()
        notifications.removeAllDeliveredNotifications()
        if UIApplication.shared.alternateIconName != nil {
            UIApplication.shared.setAlternateIconName(nil, completionHandler: nil)
        }
        Task.detached {
            for activity in Activity<BagActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            try? await CSSearchableIndex.default().deleteAllSearchableItems()
        }
    }

    // MARK: - Links

    enum Destination: Equatable { case stash, scan, pick, bag(UUID), note(UUID) }
    /// Set when another tab asks the collection to open the photo picker.
    var pendingPhotoPick = false
    /// The live "do I have this?" scanner.
    var showingChecker = false
    var showingSettings = false
    #if DEBUG
    var debugStrain: StrainInfo?
    #endif
    var destination: Destination?
    /// While the Face ID lock is up, links wait instead of opening.
    var isLocked = false

    func handle(_ url: URL) {
        guard url.scheme == "taima" else { return }
        switch url.host() {
        case "scan": destination = .scan
        case "bag": if let id = UUID(uuidString: url.lastPathComponent) { destination = .bag(id) }
        case "note": if let id = UUID(uuidString: url.lastPathComponent) { destination = .note(id) }
        default: destination = .stash
        }
    }


    /// The bundled strain library: curated lineage and aliases over the
    /// community dataset. Loaded on first use.
    @ObservationIgnored private var loadedCatalog: StrainCatalog?

    /// Loaded in the background at launch; built on first use if needed sooner.
    var strainCatalog: StrainCatalog {
        if let loadedCatalog { return loadedCatalog }
        let catalog = Self.loadCatalog()
        loadedCatalog = catalog
        return catalog
    }

    nonisolated private static func loadCatalog() -> StrainCatalog {
        StrainCatalog(curated: LibraryStore.data("strains-curated"), community: LibraryStore.data("strains"))
    }

    /// After a library download: rebuild from the new files.
    func reloadCatalog() {
        catalogGeneration += 1
        let generation = catalogGeneration
        Task.detached(priority: .utility) {
            let catalog = Self.loadCatalog()
            await MainActor.run {
                // A newer reload wins over an older one.
                if self.catalogGeneration == generation { self.loadedCatalog = catalog }
            }
        }
    }

    @ObservationIgnored private var catalogGeneration = 0

    let updates = UpdateService()

    private func preloadCatalog() {
        Task.detached(priority: .utility) {
            let catalog = Self.loadCatalog()
            await MainActor.run {
                if self.loadedCatalog == nil, self.catalogGeneration == 0 { self.loadedCatalog = catalog }
            }
        }
    }

    func isWished(_ strain: StrainInfo) -> Bool { wishlist.contains { $0.key == strain.id } }

    func toggleWish(_ strain: StrainInfo) {
        if isWished(strain) {
            try? store?.removeWish(key: strain.id)
        } else {
            try? store?.addWish(WishItem(key: strain.id, name: strain.name))
        }
        wishlist = (try? store?.wishlist()) ?? wishlist
    }

    /// Your bags whose name refers to this library strain.
    func bags(of strain: StrainInfo) -> [Bag] {
        bags.filter { strainCatalog.match(productName: $0.name)?.info.id == strain.id }
    }

    var shopSuggestions: [(name: String, city: String?)] {
        SpendingSummary(bags: bags).shops.map { ($0.name, $0.city) }
    }

    var growerSuggestions: [String] {
        var seen = Set<String>()
        return (bags.compactMap(\.producer) + GrowerDirectory.names)
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
            .sorted()
    }

    var producerNames: [String] {
        Array(Set(bags.compactMap(\.producer).filter { !$0.isEmpty })).sorted()
    }

    func bag(id: UUID) -> Bag? { bags.first { $0.id == id } }

    func duplicate(of draft: Bag) -> Bag? {
        guard let productID = draft.productID, !productID.isEmpty else { return nil }
        return bags.first { $0.id != draft.id && $0.productID == productID }
    }

    // MARK: - Saving

    /// Returns false, with `problem` set, when nothing was written.
    @discardableResult
    func save(_ draft: BagDraft, quietly: Bool = false) -> Bool {
        guard let store else {
            problem = String(localized: "Your collection is not open, so the bag was not saved. Restart Taima and try again.")
            return false
        }
        var bag = draft.bag
        var removedPhotos: [String] = []
        if let original = draft.original, let stored = self.bag(id: bag.id) {
            bag = Bag.merge(edited: bag, original: original, stored: stored)
            removedPhotos = stored.storedPhotoNames.filter { !bag.storedPhotoNames.contains($0) }
        }
        bag.name = bag.name.trimmingCharacters(in: .whitespacesAndNewlines)
        bag.producer = bag.producer?.trimmingCharacters(in: .whitespacesAndNewlines)
        if bag.producer?.isEmpty == true { bag.producer = nil }
        bag.updatedAt = .now
        do {
            try store.save(bag)
            // Only once the record no longer points at them.
            removedPhotos.forEach(photos.delete)
            if let producer = bag.producer {
                try? store.remember(producer: producer, for: draft.producerKeys)
            }
            if let index = bags.firstIndex(where: { $0.id == bag.id }) {
                bags[index] = bag
            } else {
                // A new collection is read by the current reader; nothing to re-read.
                if bags.isEmpty { markReviewed() }
                bags.append(bag)
            }
            bags.sort { $0.collectedOn > $1.collectedOn }
            refreshShared()
            checkMilestones()
            if !quietly {
                showSaved(bag.displayName)
                if bag.stock == .open, currentBagID == nil || currentBag?.stock != .open {
                    setCurrent(bag.id)
                } else if bag.id == currentBagID {
                    if bag.stock != .open { setCurrent(nil) } else { syncActivity() }
                }
            }
            return true
        } catch {
            problem = String(localized: "The bag could not be saved. \(error.localizedDescription)")
            return false
        }
    }

    func delete(_ bag: Bag) {
        do {
            guard let store else { throw StoreError.sqlite(String(localized: "the collection is not open")) }
            try store.delete(id: bag.id)
            bag.storedPhotoNames.forEach(photos.delete)
            bags.removeAll { $0.id == bag.id }
            if currentBagID == bag.id { setCurrent(nil) }
            refreshShared()
        } catch {
            problem = String(localized: "The bag could not be deleted. \(error.localizedDescription)")
        }
    }

    // MARK: - Drafts

    /// New bags start in the state the person chose last time.
    @ObservationIgnored
    @AppStorage("editor.defaultStock") var defaultStock = StockState.empty

    func startManualDraft() {
        drafts.append(BagDraft(bag: Bag(stock: defaultStock), isNew: true))
    }

    func startEditing(_ bag: Bag) {
        drafts.append(BagDraft(bag: bag, isNew: false, original: bag))
    }

    /// Finishes the front draft. Discarding a new draft removes its photo.
    func finishDraft(_ draft: BagDraft, saved: Bool) {
        if saved {
            // Keep the draft open when saving fails, so no edits are lost.
            guard save(draft) else { return }
            if draft.isNew, let stored = bag(id: draft.id) { learn(from: draft, saved: stored) }
        } else if draft.isNew {
            draft.bag.storedPhotoNames.forEach(photos.delete)
        } else {
            // Photos added while editing, then cancelled.
            let kept = bag(id: draft.id)?.storedPhotoNames ?? []
            for name in draft.bag.storedPhotoNames where !kept.contains(name) { photos.delete(name) }
        }
        drafts.removeAll { $0.id == draft.id }
    }

    /// Loads and reads picked photos one at a time, so progress shows at once
    /// and only one full-size photo is in memory.
    /// With `paired`, photos are taken as front, back, front, back.
    func importPhotos(_ items: [PhotosPickerItem], paired: Bool = false) async {
        guard !items.isEmpty, scanProgress == nil else { return }
        scanProgress = (0, items.count)
        defer { scanProgress = nil }
        var failed = 0
        var index = 0
        while index < items.count {
            let front = await load(items[index])
            let back = paired && index + 1 < items.count ? await load(items[index + 1]) : nil
            if let front {
                await read(front.image, capturedAt: front.date)
                if let back, let last = drafts.indices.last {
                    drafts[last] = await addingBack(back.image, to: drafts[last])
                }
            } else {
                failed += 1
            }
            index += paired ? 2 : 1
            scanProgress = (min(index, items.count), items.count)
        }
        if failed > 0 {
            problem = String(localized: "\(failed) photos could not be opened.")
        }
    }

    private func load(_ item: PhotosPickerItem) async -> (image: UIImage, date: Date?)? {
        guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return nil }
        return (image, PhotoStore.captureDate(in: data))
    }

    /// Reads the back of a bag and fills what the front left empty.
    func addingBack(_ image: UIImage, to draft: BagDraft) async -> BagDraft {
        let photos = self.photos
        let (back, name) = await Task.detached(priority: .userInitiated) { () -> (LabelReading, String?) in
            let prepared = Self.prepare(image)
            return (prepared.reading, try? photos.save(prepared.photo))
        }.value
        var updated = draft
        if let old = updated.bag.backPhotoName, !(bag(id: draft.id)?.storedPhotoNames.contains(old) ?? false) { photos.delete(old) }
        updated.bag.backPhotoName = name
        return applyBack(back, to: updated)
    }

    /// Fills what the front left empty with what the back says.
    private func applyBack(_ back: LabelReading, to draft: BagDraft) -> BagDraft {
        var updated = draft
        updated.bag.backRecognizedText = back.text
        updated.producerKeys += back.producerKeys.filter { !updated.producerKeys.contains($0) }
        func fill<Value>(_ path: WritableKeyPath<Bag, Value?>, _ value: Value?, _ field: LabelField) {
            guard updated.bag[keyPath: path] == nil, let value else { return }
            updated.bag[keyPath: path] = value
            updated.detected.insert(field)
        }
        let remembered = try? store?.producer(for: back.producerKeys)
        fill(\.producer, remembered ?? back.producer, .producer)
        fill(\.thc, back.thc, .thc)
        fill(\.cbd, back.cbd, .cbd)
        fill(\.grams, back.grams, .grams)
        fill(\.harvestedOn, back.harvestedOn, .harvestedOn)
        fill(\.packedOn, back.packedOn, .packedOn)
        fill(\.bestBeforeOn, back.bestBeforeOn, .bestBeforeOn)
        for (field, confidence) in back.confidence where updated.detected.contains(field) && confidence.needsReview {
            updated.doubtful.insert(field)
        }
        fill(\.productID, back.productID, .productID)
        fill(\.sku, back.sku, .sku)
        fill(\.ean, back.ean, .ean)
        fill(\.leafletURL, back.leafletURL, .leafletURL)
        fill(\.strainType, back.strainType, .strainType)
        fill(\.unitCount, back.unitCount, .unitCount)
        if updated.bag.form == .bag, let form = back.form, form != .bag {
            updated.bag.form = form
            updated.detected.insert(.form)
        }
        if updated.bag.name.isEmpty, let name = back.name {
            updated.bag.name = name
            updated.detected.insert(.name)
        }
        return updated
    }

    // MARK: - Photos

    /// Saves a photo of the flower to the draft; the first one becomes main.
    func addingFlowerPhoto(_ image: UIImage, to draft: BagDraft) async -> BagDraft {
        let photos = self.photos
        let name = await Task.detached(priority: .userInitiated) {
            try? photos.save(image.resized(maxSide: PhotoStore.readingSize))
        }.value
        guard let name else { return draft }
        var updated = draft
        updated.bag.extraPhotoNames = (updated.bag.extraPhotoNames ?? []) + [name]
        if updated.bag.extraPhotoNames?.count == 1 { updated.bag.coverPhotoName = name }
        return updated
    }

    /// Swaps the label photo and reads it, filling only fields still empty:
    /// nothing the person typed is overwritten.
    func replacingFront(_ image: UIImage, in draft: BagDraft) async -> BagDraft {
        let photos = self.photos
        let (reading, name) = await Task.detached(priority: .userInitiated) { () -> (LabelReading, String?) in
            let prepared = Self.prepare(image)
            return (prepared.reading, try? photos.save(prepared.photo))
        }.value
        guard let name else { return draft }
        var updated = draft
        if let old = updated.bag.photoName, !(bag(id: draft.id)?.storedPhotoNames.contains(old) ?? false) { photos.delete(old) }
        if updated.bag.coverPhotoName == updated.bag.photoName { updated.bag.coverPhotoName = nil }
        updated.bag.photoName = name
        updated.bag.recognizedText = reading.text
        updated = applyBack(reading, to: updated)
        updated.bag.backRecognizedText = draft.bag.backRecognizedText
        return updated
    }

    func removingPhoto(_ name: String, from draft: BagDraft) -> BagDraft {
        var updated = draft
        if updated.bag.photoName == name { updated.bag.photoName = nil }
        if updated.bag.backPhotoName == name {
            updated.bag.backPhotoName = nil
            updated.bag.backRecognizedText = nil
        }
        updated.bag.extraPhotoNames?.removeAll { $0 == name }
        if updated.bag.coverPhotoName == name { updated.bag.coverPhotoName = nil }
        // Saved files go when the edit is saved; new ones go now.
        if !(bag(id: draft.id)?.storedPhotoNames.contains(name) ?? false) { photos.delete(name) }
        return updated
    }

    func removeBack(from draft: BagDraft) -> BagDraft {
        var updated = draft
        if let old = updated.bag.backPhotoName, !(bag(id: draft.id)?.storedPhotoNames.contains(old) ?? false) { photos.delete(old) }
        updated.bag.backPhotoName = nil
        updated.bag.backRecognizedText = nil
        return updated
    }

    /// A new bag from a rotate scan: the combined reading and the clearest frame.
    func scanFused(_ reading: LabelReading, image: UIImage?) async {
        let photos = self.photos
        let name = await Task.detached(priority: .userInitiated) {
            image.flatMap { try? photos.save(LabelCleaner.clean($0.resized(maxSide: PhotoStore.readingSize)).photo) }
        }.value
        drafts.append(makeDraft(reading: reading, photoName: name, collectedOn: .now))
    }

    /// A rotate scan inside the editor: the frame becomes the label photo and
    /// the reading fills only fields that are still empty.
    func applyingFused(_ reading: LabelReading, image: UIImage?, to draft: BagDraft) async -> BagDraft {
        var updated = draft
        if let image {
            let photos = self.photos
            let name = await Task.detached(priority: .userInitiated) {
                try? photos.save(LabelCleaner.clean(image.resized(maxSide: PhotoStore.readingSize)).photo)
            }.value
            if let name {
                if let old = updated.bag.photoName, !(bag(id: draft.id)?.storedPhotoNames.contains(old) ?? false) { photos.delete(old) }
                if updated.bag.coverPhotoName == updated.bag.photoName { updated.bag.coverPhotoName = nil }
                updated.bag.photoName = name
            }
        }
        updated.bag.recognizedText = reading.text
        let back = updated.bag.backRecognizedText
        updated = applyBack(reading, to: updated)
        updated.bag.backRecognizedText = back
        return updated
    }

    /// Reads each photo's label on-device and queues a draft for review.
    func scan(_ images: [(image: UIImage, capturedAt: Date?)]) async {
        guard !images.isEmpty, scanProgress == nil else { return }
        scanProgress = (0, images.count)
        defer { scanProgress = nil }
        for (index, item) in images.enumerated() {
            await read(item.image, capturedAt: item.capturedAt)
            scanProgress = (index + 1, images.count)
        }
    }

    private func read(_ image: UIImage, capturedAt: Date?) async {
        let photos = self.photos
        let result = await Task.detached(priority: .userInitiated) { () -> (LabelReading, String?) in
            let prepared = Self.prepare(image)
            return (prepared.reading, try? photos.save(prepared.photo))
        }.value
        drafts.append(makeDraft(reading: result.0, photoName: result.1, collectedOn: capturedAt ?? .now))
    }

    /// Upright, cropped and cleaned. Both the cleaned and the original image
    /// are read: the cleaned one usually reads better, the original fills
    /// anything the crop cut off.
    nonisolated static func prepare(_ image: UIImage) -> (photo: UIImage, reading: LabelReading) {
        let upright = image.resized(maxSide: PhotoStore.readingSize)
        let cleaned = LabelCleaner.clean(upright)
        let original = upright.cgImage.map(LabelScanner.read) ?? LabelReading()
        guard cleaned.cropped, let cgImage = cleaned.image.cgImage else { return (cleaned.photo, original) }
        let fromCleaned = LabelScanner.read(cgImage)
        return (cleaned.photo, fromCleaned.merged(withBack: original))
    }

    /// Reads a saved photo the way a new scan does, so re-reading older bags
    /// gets the same crop and clean-up. The stored photo is left as it is.
    nonisolated static func reread(_ data: Data) -> LabelReading {
        guard let image = UIImage(data: data) else { return LabelReading() }
        return prepare(image).reading
    }

    private func makeDraft(reading original: LabelReading, photoName: String?, collectedOn: Date) -> BagDraft {
        var reading = original
        if learningEnabled, let name = reading.name { reading.name = correctionMemory.apply(to: name) }
        var detected = reading.detectedFields
        var producer = reading.producer
        if let remembered = try? store?.producer(for: reading.producerKeys) {
            producer = remembered
            detected.insert(.producer)
        }
        let bag = Bag(
            name: reading.name ?? "",
            producer: producer,
            strainType: reading.strainType,
            thc: reading.thc,
            cbd: reading.cbd,
            grams: reading.grams,
            harvestedOn: reading.harvestedOn,
            packedOn: reading.packedOn,
            collectedOn: collectedOn,
            productID: reading.productID,
            sku: reading.sku,
            ean: reading.ean,
            leafletURL: reading.leafletURL,
            photoName: photoName,
            recognizedText: reading.text,
            stock: defaultStock,
            form: reading.form ?? .bag,
            unitCount: reading.unitCount
        )
        var draft = BagDraft(bag: bag, isNew: true, detected: detected, producerKeys: reading.producerKeys)
        draft.originalReading = original
        draft.bag.bestBeforeOn = reading.bestBeforeOn
        draft.doubtful = Set(detected.filter { field in reading.confidence[field].map(\.needsReview) ?? false })
        // The label rarely prints indica or sativa; a confident library match can.
        if draft.bag.strainType == nil, let match = strainCatalog.match(productName: draft.bag.name),
           match.match != .partial, let type = match.info.trustedType {
            draft.bag.strainType = type
            draft.detected.insert(.strainType)
        }
        return draft
    }

    /// Rereads the label of a saved photo, for bags edited later.
    func rescan(_ draft: BagDraft) async -> BagDraft {
        guard let name = draft.bag.photoName, let data = photos.data(named: name) else { return draft }
        let reading = await Task.detached(priority: .userInitiated) {
            Self.reread(data)
        }.value
        var fresh = makeDraft(reading: reading, photoName: name, collectedOn: draft.bag.collectedOn)
        fresh.original = draft.original
        fresh.isNew = draft.isNew
        fresh.bag = fresh.bag.keepingPersonalFields(of: draft.bag)
        if let back = draft.bag.backPhotoName, let data = photos.data(named: back) {
            let backReading = await Task.detached(priority: .userInitiated) {
                Self.reread(data)
            }.value
            fresh = applyBack(backReading, to: fresh)
        }
        fresh.isNew = draft.isNew
        return fresh
    }

    // MARK: - Backup

    /// Only plain photo file names; a crafted backup must not write elsewhere.
    nonisolated static func isSafePhotoName(_ name: String) -> Bool {
        BackupArchive.isSafePhotoName(name)
    }

    /// Writes a backup archive off the main thread, one photo at a time.
    func writeBackup(to url: URL, passphrase: String?) async throws {
        let manifest = BackupArchive.Manifest(bags: bags, wishlist: wishlist, producerKeys: (try? store?.producerKeys()) ?? [:])
        let names = bags.flatMap(\.storedPhotoNames)
        let photos = self.photos
        try await Task.detached(priority: .userInitiated) {
            try BackupArchive.write(to: url, manifest: manifest, photoNames: names, photo: photos.dataForBackup(named:), passphrase: passphrase)
        }.value
    }

    func backupFile(passphrase: String?) async throws -> URL {
        let stamp = Date.now.formatted(.iso8601.year().month().day())
        let url = FileManager.default.temporaryDirectory.appending(path: "Taima \(stamp).\(BackupArchive.fileExtension)")
        try? FileManager.default.removeItem(at: url)
        try await writeBackup(to: url, passphrase: passphrase)
        return url
    }

    /// Adds bags read from a spreadsheet. Returns how many were saved.
    func importBags(_ imported: [Bag]) -> Int {
        guard let store else { return 0 }
        // Importing the same file twice doesn't duplicate bags.
        func signature(_ bag: Bag) -> String {
            [bag.strainKey, bag.producer?.lowercased() ?? "", Calendar.taima.startOfDay(for: bag.collectedOn).description].joined(separator: "|")
        }
        var seen = Set(bags.map(signature))
        var added: [Bag] = []
        for bag in imported where seen.insert(signature(bag)).inserted && (try? store.save(bag)) != nil { added.append(bag) }
        bags = (bags + added).sorted { $0.collectedOn > $1.collectedOn }
        backfillGrowers()
        refreshShared()
        return added.count
    }

    func csvFile() throws -> URL {
        let stamp = Date.now.formatted(.iso8601.year().month().day())
        let url = FileManager.default.temporaryDirectory.appending(path: "Taima-\(stamp).csv")
        try Data(CSVExport.make(bags).utf8).write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    /// Adds bags from a backup; bags already present (same id) stay as they
    /// are. Reads both archive backups and the older single-file JSON.
    @discardableResult
    func restore(from url: URL, passphrase: String? = nil) async throws -> Int {
        guard let store else { throw StoreError.sqlite(String(localized: "the collection is not open")) }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let photos = self.photos
        // Files and photos off the main thread; photos are re-encoded so a
        // foreign backup can't carry metadata in, and never overwrite.
        let manifest = try await Task.detached(priority: .userInitiated) { () -> BackupArchive.Manifest in
            func keep(_ name: String, _ data: Data) {
                guard Self.isSafePhotoName(name), !FileManager.default.fileExists(atPath: photos.url(for: name).path) else { return }
                try? photos.saveReencoded(data: data, named: name)
            }
            if BackupArchive.isArchive(url) {
                return try BackupArchive.read(from: url, passphrase: passphrase) { name, data in keep(name, data) }
            }
            let legacy = try CollectionBackup.decode(Data(contentsOf: url))
            for (name, data) in legacy.photos { keep(name, data) }
            return BackupArchive.Manifest(bags: legacy.bags, wishlist: legacy.wishlist ?? [], producerKeys: [:], exportedAt: legacy.exportedAt)
        }.value

        for item in manifest.wishlist { try? store.addWish(item) }
        wishlist = (try? store.wishlist()) ?? wishlist
        for (key, producer) in manifest.producerKeys { try? store.remember(producer: producer, for: [key]) }
        let existing = Set(bags.map(\.id))
        var restored: [Bag] = []
        for bag in manifest.bags where !existing.contains(bag.id) {
            var bag = bag
            func present(_ name: String?) -> String? {
                guard let name, Self.isSafePhotoName(name), FileManager.default.fileExists(atPath: photos.url(for: name).path) else { return nil }
                return name
            }
            bag.photoName = present(bag.photoName)
            bag.backPhotoName = present(bag.backPhotoName)
            bag.extraPhotoNames = bag.extraPhotoNames?.compactMap(present)
            if let cover = bag.coverPhotoName, !bag.photoNames.contains(cover) { bag.coverPhotoName = nil }
            bag.timedNotes = bag.timedNotes?.map { note in
                var note = note
                note.photoName = present(note.photoName)
                return note
            }
            try store.save(bag)
            restored.append(bag)
        }
        bags = (bags + restored).sorted { $0.collectedOn > $1.collectedOn }
        backfillGrowers()
        tidyCurrent()
        refreshShared()
        // A restore brings back old achievements; it doesn't earn them.
        checkMilestones(silently: true)
        newMilestone = nil
        return restored.count
    }

    // MARK: - Shared surfaces

    private func showSaved(_ name: String) {
        savedName = name
        Task {
            try? await Task.sleep(for: .seconds(2))
            if savedName == name { savedName = nil }
        }
    }

    /// Updates the widgets' snapshot and the Spotlight index.
    @ObservationIgnored private var sharedTask: Task<Void, Never>?

    /// Updates the widgets' snapshot and the Spotlight index. Runs one at a
    /// time, so an older snapshot can never land after a newer one.
    func refreshShared() {
        let bags = self.bags
        let photos = self.photos
        let currentID = currentBagID
        let previous = sharedTask
        sharedTask = Task.detached(priority: .utility) {
            await previous?.value
            var hasThumbnail = false
            if SharedContainer.isDiscreet, let thumbURL = SharedContainer.thumbnailURL {
                try? FileManager.default.removeItem(at: thumbURL)
            } else if let latest = bags.max(by: { $0.collectedOn < $1.collectedOn }), let name = latest.mainPhoto,
               let thumbURL = SharedContainer.thumbnailURL,
               let image = UIImage(contentsOfFile: photos.thumbnailURL(for: name).path)?.resized(maxSide: 300),
               let data = image.jpegData(compressionQuality: 0.7) {
                hasThumbnail = (try? data.write(to: thumbURL, options: .atomic)) != nil
            }
            if let url = SharedContainer.snapshotURL,
               let data = try? JSONEncoder().encode(WidgetSnapshot(bags: bags, hasThumbnail: hasThumbnail, currentID: currentID)) {
                try? data.write(to: url, options: .atomic)
            }
            WidgetCenter.shared.reloadAllTimelines()
            await SpotlightIndexer.shared.update(bags)
        }
    }


    #if DEBUG
    /// Simulator testing: TAIMA_IMPORT_DIR scans every image in a folder;
    /// TAIMA_AUTOSAVE=1 saves the resulting drafts unreviewed.
    func debugImport() async {
        let environment = ProcessInfo.processInfo.environment
        if let backup = environment["TAIMA_RESTORE"] ?? UserDefaults.standard.string(forKey: "TAIMA_RESTORE"), bags.isEmpty {
            _ = try? await restore(from: URL(fileURLWithPath: backup))
        }
        if let target = environment["TAIMA_OPEN"] ?? UserDefaults.standard.string(forKey: "TAIMA_OPEN"), let bag = bags.first(where: { $0.stock == .open }) ?? bags.first {
            try? await Task.sleep(for: .seconds(1))
            if target == "edit" { startEditing(bag) } else if target == "strain", let info = strainCatalog.info(named: "Girl Scout Cookies") {
                debugStrain = info
            } else { destination = .bag(bag.id) }
        }
        if let folder = environment["TAIMA_CLEAN_TEST"] {
            // Writes LabelCleaner's output for each image, to inspect crops.
            let urls = (try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: folder), includingPropertiesForKeys: nil)) ?? []
            for url in urls where url.pathExtension == "jpg" && !url.lastPathComponent.hasPrefix("out-") {
                guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { continue }
                let result = LabelCleaner.clean(image.resized(maxSide: PhotoStore.readingSize))
                try? result.image.jpegData(compressionQuality: 0.7)?.write(to: URL(fileURLWithPath: folder + "/out-" + url.lastPathComponent))
                let reading = Self.prepare(image).reading
                let summary = reading.text + "\n---\nTHC " + (reading.thc?.label ?? "-") + ", CBD " + (reading.cbd?.label ?? "-")
                try? summary.write(to: URL(fileURLWithPath: folder + "/out-" + url.lastPathComponent + ".txt"), atomically: true, encoding: .utf8)
            }
        }
        if environment["TAIMA_ERASE"] == "1", !bags.isEmpty {
            try? await Task.sleep(for: .seconds(2))
            try? await eraseEverything()
        }
        guard let folder = environment["TAIMA_IMPORT_DIR"], bags.isEmpty else { return }
        let urls = (try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: folder), includingPropertiesForKeys: nil)) ?? []
        let images = urls.sorted { $0.path < $1.path }.compactMap { url -> (UIImage, Date?)? in
            guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { return nil }
            return (image, PhotoStore.captureDate(in: data))
        }
        await scan(images)
        if environment["TAIMA_AUTOSAVE"] == "1" {
            // Saves drafts without the editor; TAIMA_UI_SAVE exercises the sheet queue instead.
            for draft in drafts { finishDraft(draft, saved: true) }
        }
        if environment["TAIMA_DEMO_STOCK"] == "1", bags.count >= 6 {
            let calendar = Calendar.taima
            for (index, bag) in bags.enumerated() {
                update(bag.id) { bag in
                    bag.collectedOn = calendar.date(byAdding: .day, value: -index * 17, to: .now) ?? .now
                    bag.stock = index < 3 ? .full : .empty
                    bag.remainingGrams = index < 3 ? bag.grams : 0
                }
            }
            if let first = bags.first(where: { $0.stock == .full && ($0.grams ?? 0) >= 5 }) {
                open(first)
                for day in 0..<12 {
                    update(first.id) { $0.use(0.15 + Double(day % 3) * 0.05, at: calendar.date(byAdding: .day, value: -day, to: .now)!) }
                }
                syncActivity()
            }
        }
    }
    #endif
}

/// Keeps Spotlight in step with the collection, touching only bags that
/// changed. Empty while discreet mode or the Face ID lock is on.
actor SpotlightIndexer {
    static let shared = SpotlightIndexer()
    private var indexed: [String: Int] = [:]
    private var loaded = false

    func update(_ bags: [Bag]) async {
        let index = CSSearchableIndex.default()
        guard !SharedContainer.isDiscreet, !UserDefaults.standard.bool(forKey: "privacy.lock") else {
            if !indexed.isEmpty || !loaded {
                try? await index.deleteSearchableItems(withDomainIdentifiers: ["bags"])
                indexed = [:]
                loaded = true
            }
            return
        }
        var wanted: [String: (Int, CSSearchableItem)] = [:]
        for bag in bags {
            let description = [bag.producer, bag.thc.map { "THC \($0.label)" }, bag.grams?.gramsLabel].compactMap { $0 }.joined(separator: " · ")
            var hasher = Hasher()
            hasher.combine(bag.displayName)
            hasher.combine(description)
            let attributes = CSSearchableItemAttributeSet(contentType: .content)
            attributes.title = bag.displayName
            attributes.contentDescription = description
            wanted[bag.id.uuidString] = (hasher.finalize(), CSSearchableItem(uniqueIdentifier: bag.id.uuidString, domainIdentifier: "bags", attributeSet: attributes))
        }
        if !loaded {
            // First run this launch: start from a clean slate once.
            try? await index.deleteSearchableItems(withDomainIdentifiers: ["bags"])
            loaded = true
        }
        let removed = indexed.keys.filter { wanted[$0] == nil }
        if !removed.isEmpty { try? await index.deleteSearchableItems(withIdentifiers: Array(removed)) }
        let changed = wanted.filter { indexed[$0.key] != $0.value.0 }
        if !changed.isEmpty { try? await index.indexSearchableItems(changed.values.map(\.1)) }
        indexed = wanted.mapValues(\.0)
    }
}
