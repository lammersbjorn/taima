import PhotosUI
import SwiftUI
import TaimaCore

enum CollectionMode: String, CaseIterable, Identifiable {
    case bags, strains
    var id: String { rawValue }
    var label: String { self == .bags ? String(localized: "All") : String(localized: "By strain") }
}

struct CollectionView: View {
    @Environment(AppModel.self) private var model
    @Namespace private var zoom
    @AppStorage("collection.mode") private var mode = CollectionMode.bags
    @State private var pairedImport = false
    @AppStorage("collection.sort") private var sort = BagSort.newest
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showingPicker = false
    @State private var pendingDelete: Bag?
    @State private var comparing: Bag?
    @State private var rotateScanning = false

    private var visibleBags: [Bag] {
        let filtered = model.bags
        switch sort {
        case .newest: return filtered.sorted { $0.collectedOn > $1.collectedOn }
        case .oldest: return filtered.sorted { $0.collectedOn < $1.collectedOn }
        case .strongest: return filtered.sorted { ($0.thc?.percent ?? -1) > ($1.thc?.percent ?? -1) }
        case .heaviest: return filtered.sorted { ($0.grams ?? -1) > ($1.grams ?? -1) }
        case .name: return filtered.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if model.bags.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Collection")
            .navigationDestination(for: StrainInfo.self) { StrainInfoView(strain: $0) }
            .navigationDestination(for: UUID.self) { id in
                BagDetailView(id: id)
                    .navigationTransition(.zoom(sourceID: id, in: zoom))
            }
            .navigationDestination(for: StrainGroup.self) { group in
                StrainDetailView(key: group.key)
                    .navigationTransition(.zoom(sourceID: group.key, in: zoom))
            }
            .toolbar {
                if !model.bags.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            Picker("Sort", selection: $sort) {
                                ForEach(BagSort.allCases) { Text($0.label).tag($0) }
                            }
                        } label: {
                            Label("Sort", systemImage: "arrow.up.arrow.down")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    SettingsToolbarButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    addMenu
                }
            }
            .photosPicker(isPresented: $showingPicker, selection: $pickerItems, maxSelectionCount: 30, matching: .images, photoLibrary: .shared())
            .onChange(of: pickerItems) { _, items in
                guard !items.isEmpty else { return }
                pickerItems = []
                let paired = pairedImport
                Task { await model.importPhotos(items, paired: paired) }
            }
            .onChange(of: model.pendingPhotoPick) { _, pending in
                guard pending else { return }
                model.pendingPhotoPick = false
                pairedImport = false
                showingPicker = true
            }
            .sheet(item: $comparing) { bag in ComparePicker(first: bag) }
            .fullScreenCover(isPresented: $rotateScanning) {
                RotateScanView { reading, image in
                    Task { await model.scanFused(reading, image: image) }
                }
            }
            .onChange(of: model.pendingCameraScan) { _, pending in
                guard pending else { return }
                model.pendingCameraScan = false
                if Camera.isAvailable { scanWithCamera() } else { showingPicker = true }
            }
            .confirmationDialog(
                "Delete \(pendingDelete?.displayName ?? String(localized: "bag"))?",
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let pendingDelete { model.delete(pendingDelete) }
                }
            } message: {
                Text("It and its photos are removed from this iPhone.")
            }
        }
    }

    private var visibleStrains: [StrainGroup] { model.strains }

    private var list: some View {
        List {
            Section {
                Picker("Show", selection: $mode.animation(.snappy)) {
                    ForEach(CollectionMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowBackground(Color.clear)
            }
            if model.reviewIsOwed {
                Section {
                    Button {
                        model.showingEntryReview = true
                    } label: {
                        HStack(spacing: 12) {
                            TintedIconTile(systemImage: "wand.and.sparkles", hue: Theme.leafMid, size: 38)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Improve older entries").font(.headline).foregroundStyle(.primary)
                                Text("Taima reads labels better now. Re-read your bags and review what it would add.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            if mode == .strains {
                Section {
                    ForEach(visibleStrains) { group in
                        NavigationLink(value: group) {
                            StrainRow(group: group)
                                .matchedTransitionSource(id: group.key, in: zoom)
                        }
                    }
                } header: {
                    Text(String(localized: "\(visibleStrains.count) strains"))
                }
            } else {
            Section {
                ForEach(visibleBags) { bag in
                    NavigationLink(value: bag.id) {
                        BagRow(bag: bag)
                            .matchedTransitionSource(id: bag.id, in: zoom)
                    }
                    .contextMenu {
                        if bag.stock != .empty {
                            Button("Use this bag", systemImage: "leaf") { model.open(bag) }
                        }
                        Button("Edit", systemImage: "pencil") { model.startEditing(bag) }
                        Button("Compare with…", systemImage: "rectangle.split.2x1") { comparing = bag }
                        Button("Delete", systemImage: "trash", role: .destructive) { pendingDelete = bag }
                    } preview: {
                        BagPhoto(name: bag.mainPhoto, thumbnail: false)
                            .frame(width: 300, height: 300)
                    }
                    .swipeActions {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            pendingDelete = bag
                        }
                        Button("Edit", systemImage: "pencil") {
                            model.startEditing(bag)
                        }
                        .tint(.accentColor)
                    }
                }
            }
            }
        }
        .scrollContentBackground(.hidden)
        .background(GlowBackground())
    }

    private func scanWithCamera() {
        Camera.capture { image in
            Task { await model.scan([(image, .now)]) }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nothing here yet", systemImage: "bag")
        } description: {
            Text("Photograph the label of a bag, preroll pack, jar or hash. Taima reads the name, THC, weight and dates on this iPhone, and you check them before saving.")
        } actions: {
            if Camera.isAvailable {
                Button("Scan a label", systemImage: "camera") { scanWithCamera() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.solid)
                    .controlSize(.large)
            }
            Button("Choose photos", systemImage: "photo.on.rectangle") { pairedImport = false; showingPicker = true }
                .buttonStyle(.bordered)
                .controlSize(.large)
            Button("Add without photo") { model.startManualDraft() }
                .font(.footnote)
        }
    }

    private var addMenu: some View {
        Menu {
            if Camera.isAvailable {
                Button("Scan a label", systemImage: "camera") { scanWithCamera() }
            }
            Button("Choose photos", systemImage: "photo.on.rectangle") { pairedImport = false; showingPicker = true }
            Button("Front and back pairs", systemImage: "rectangle.on.rectangle") { pairedImport = true; showingPicker = true }
            if Camera.isAvailable {
                Button("Rotate to scan a preroll or jar", systemImage: "arrow.triangle.2.circlepath.camera") { rotateScanning = true }
            }
            Divider()
            Button("Check a bag in the shop", systemImage: "barcode.viewfinder") { model.showingChecker = true }
            Button("Add without photo", systemImage: "square.and.pencil") { model.startManualDraft() }
        } label: {
            Label("Add", systemImage: "plus")
        }
        .accessibilityIdentifier("collection.add")
    }
}

struct BagRow: View {
    let bag: Bag

    var body: some View {
        HStack(spacing: 12) {
            BagPhoto(name: bag.mainPhoto)
                .frame(width: 58, height: 58)
                .clipShape(.rect(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 5) {
                Text(bag.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Text(bag.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                // Drops the least important chips when the row is narrow or
                // the text is large, instead of squeezing every chip.
                ViewThatFits(in: .horizontal) {
                    chips(score: true, grams: true, type: true)
                    chips(score: true, grams: true, type: false)
                    chips(score: true, grams: false, type: false)
                    chips(score: false, grams: false, type: false)
                    StockBadge(bag: bag).fixedSize()
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func chips(score: Bool, grams: Bool, type: Bool) -> some View {
        HStack(spacing: 6) {
            StockBadge(bag: bag)
            if bag.form != .bag {
                Image(systemName: bag.form.symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(bag.form.label)
            }
            if let thc = bag.thc { Chip(title: "THC", value: thc.label, prominent: false) }
            if score, let value = bag.rating10 {
                Chip(title: "★", value: value.formatted(.number.precision(.fractionLength(0...1))))
                    .accessibilityLabel("Score \(value.formatted(.number.precision(.fractionLength(0...1)))) of 10")
            }
            if grams, let value = bag.grams { Chip(title: "", value: value.gramsLabel) }
            if type, let value = bag.strainType { Chip(title: "", value: value.label) }
        }
        .fixedSize()
    }
}

struct StrainRow: View {
    let group: StrainGroup

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                BagPhoto(name: group.photoName)
                    .frame(width: 58, height: 58)
                    .clipShape(.rect(cornerRadius: 12))
                if group.bags.count > 1 {
                    Text("×\(group.bags.count)")
                        .accessibilityLabel(ItemCount.label(group.bags))
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Theme.solid, in: .capsule)
                        .foregroundStyle(.white)
                        .offset(x: 6, y: 6)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name).font(.headline).lineLimit(2)
                Text([group.producers.first, "\(ItemCount.label(group.bags)) · \(group.totalGrams.gramsLabel)"]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let thc = group.averageTHC {
                    Chip(title: "THC", value: thc.formatted(.number.precision(.fractionLength(0...1))) + "%", prominent: true)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
