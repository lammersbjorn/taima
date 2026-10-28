import SwiftUI
import TaimaCore

struct BagDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let id: UUID
    @State private var confirmingDelete = false
    @State private var showingPhoto: String?
    @State private var deducting: Bag?
    @State private var confirmingLookup: String?
    @State private var comparing: Bag?
    @State private var sharing: Bag?
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let bag = model.bag(id: id) {
            content(bag)
        } else {
            ContentUnavailableView("Removed", systemImage: "trash")
        }
    }

    private func content(_ bag: Bag) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    if !bag.photoNames.isEmpty {
                        TabView {
                            ForEach(bag.galleryPhotos, id: \.self) { name in
                                Button { showingPhoto = name } label: {
                                    BagPhoto(name: name, thumbnail: false)
                                        .frame(height: 260)
                                        .clipShape(.rect(cornerRadius: Theme.mediaRadius))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(name == bag.backPhotoName ? String(localized: "Show back photo") : String(localized: "Show photo"))
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: bag.photoNames.count > 1 ? .always : .never))
                        .frame(height: 270)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(bag.displayName)
                            .font(.largeTitle.bold())
                            .fontDesign(.rounded)
                        if let producer = bag.producer {
                            Text(producer)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }
                    figures(bag)
                    if bag.stock == .open {
                        Button {
                            deducting = bag
                        } label: {
                            Label("Log a session", systemImage: "square.and.pencil")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.solid)
                        .controlSize(.large)
                        if let last = model.sessionToRepeat(for: bag) {
                            Button {
                                withAnimation { model.repeatLastSession(in: bag) }
                            } label: {
                                Label(String(localized: "Repeat last · \(last.summary)"), systemImage: "arrow.clockwise")
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(Theme.leafMid)
                            .controlSize(.large)
                            .sensoryFeedback(.success, trigger: bag.usage.count)
                        }
                    }
                    if let again = bag.wouldBuyAgain {
                        Label(again ? String(localized: "Would buy again") : String(localized: "Wouldn't buy again"), systemImage: again ? "hand.thumbsup.fill" : "hand.thumbsdown")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(again ? Theme.leafMid : .secondary)
                    }
                    if let score = bag.rating10 {
                        HStack(spacing: 10) {
                            HalfStars(score: score, size: .title3)
                            Text(score.formatted(.number.precision(.fractionLength(0...1))) + " / 10")
                                .font(.headline)
                                .monospacedDigit()
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                .listRowBackground(Color.clear)
            }

            inventorySection(bag)

            BagTimelineSection(bag: bag) { model.noteTarget = bag }

            if !(bag.positiveEffects.isEmpty && bag.negativeEffects.isEmpty && bag.flavorTags.isEmpty) {
                Section("Experience") {
                    if !bag.positiveEffects.isEmpty {
                        labelledTags(String(localized: "Effects"), bag.positiveEffects, Theme.leafMid)
                    }
                    if !bag.negativeEffects.isEmpty {
                        labelledTags(String(localized: "Downsides"), bag.negativeEffects, .orange)
                    }
                    if !bag.flavorTags.isEmpty {
                        labelledTags(String(localized: "Taste and smell"), bag.flavorTags, .teal)
                    }
                }
            }

            if LibraryLink.hasContent(for: bag.name, in: model.strainCatalog) {
                Section {
                    LibraryLink(productName: bag.name)
                }
            }

            Section("Dates") {
                // Only the dates that are known; Edit adds the others.
                if let harvested = bag.harvestedOn {
                    row(String(localized: "Harvested"), harvested.formatted(date: .abbreviated, time: .omitted))
                }
                if let packed = bag.packedOn {
                    row(String(localized: "Packed"), packed.formatted(date: .abbreviated, time: .omitted))
                }
                if let bestBefore = bag.bestBeforeOn {
                    row(String(localized: "Best before"), bestBefore.formatted(date: .abbreviated, time: .omitted))
                }
                row(String(localized: "Collected"), bag.collectedOn.formatted(date: .abbreviated, time: .omitted))
                if let days = bag.cureDays {
                    row(String(localized: "Harvest to pack"), String(localized: "\(days) days"))
                }
            }

            if !bag.notes.isEmpty || bag.priceEuros != nil || bag.shop != nil {
                Section("Yours") {
                    if let shop = bag.shop {
                        row(String(localized: "Bought at"), [shop, bag.shopCity].compactMap { $0 }.joined(separator: ", "))
                    }
                    if let price = bag.priceEuros {
                        row(String(localized: "Price"), price.formatted(.currency(code: "EUR")))
                    }
                    if let perGram = bag.pricePerGram, bag.grams != 1 {
                        row(String(localized: "Per gram"), perGram.formatted(.currency(code: "EUR")))
                    }
                    if !bag.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes").font(.caption).foregroundStyle(.secondary)
                            Text(bag.notes)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }

            Section("Codes") {
                code(String(localized: "Product ID"), bag.productID)
                code("SKU", bag.sku)
                code("EAN", bag.ean)
                if let productID = bag.productID, ProductCodeLookup.url(for: productID) != nil {
                    Button("Look up product code online", systemImage: "globe") { confirmingLookup = productID }
                }
                if let leaflet = bag.leafletURL {
                    SafeLinkButton(title: String(localized: "Package leaflet"), systemImage: "doc.text", address: leaflet)
                }
            }

            if let back = bag.backRecognizedText, !back.isEmpty {
                Section {
                    DisclosureGroup("Text read from the back") {
                        Text(back)
                            .font(.footnote.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }

            if !bag.recognizedText.isEmpty {
                Section {
                    DisclosureGroup("Text read from the label") {
                        Text(bag.recognizedText)
                            .font(.footnote.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Share card", systemImage: "square.and.arrow.up") { sharing = bag }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { model.startEditing(bag) }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Compare with…", systemImage: "rectangle.split.2x1") { comparing = bag }
                    Button("Delete", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
            }
        }
        .confirmationDialog("Delete \(bag.displayName)?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                model.delete(bag)
                dismiss()
            }
        } message: {
            Text("This \(bag.form.noun) and its photos are removed from this iPhone.")
        }
        .fullScreenCover(item: $showingPhoto) { name in
            PhotoViewer(name: name)
        }
        .confirmationDialog("Look up on Potspot?", isPresented: Binding(get: { confirmingLookup != nil }, set: { if !$0 { confirmingLookup = nil } }), titleVisibility: .visible) {
            Button("Open potspot.nl") {
                if let id = confirmingLookup, let url = ProductCodeLookup.url(for: id) {
                    openURL(url)
                }
            }
        } message: {
            Text("This opens a community website in Safari and sends it this bag's product code. Taima itself sends nothing. The site may not know the code.")
        }
        .sheet(item: $comparing) { bag in ComparePicker(first: bag) }
        .sheet(item: $sharing) { bag in ShareCardSheet(bag: bag) }
        .sheet(item: $deducting) { bag in
            DeductSheet(bag: bag).presentationDetents([.medium, .large])
        }
        .background(GlowBackground())
        .scrollContentBackground(.hidden)
    }

    private func labelledTags(_ title: String, _ tags: [String], _ hue: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TagCloud(tags: tags.map { ($0, nil) }, hue: hue)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder private func inventorySection(_ bag: Bag) -> some View {
        Section {
            Picker("Stock", selection: Binding(get: { bag.stock }, set: { model.setStock($0, for: bag) })) {
                ForEach(StockState.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            if bag.stock == .open {
                HStack(spacing: 16) {
                    RemainingRing(fraction: bag.fractionLeft ?? 1, remaining: bag.remaining)
                        .frame(width: 84, height: 84)
                    VStack(alignment: .leading, spacing: 8) {
                        if model.currentBagID == bag.id {
                            Label("Your current bag", systemImage: "leaf.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.leaf)
                        } else {
                            Button("Make current bag", systemImage: "leaf") { model.setCurrent(bag.id) }
                                .buttonStyle(.bordered)
                                .tint(Theme.leafMid)
                        }
                        if !bag.usage.isEmpty {
                            Text("Used \(bag.usedGrams.gramsLabel) in \(bag.usage.count) sessions")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            } else if bag.stock == .full {
                Button("Open and start using", systemImage: "bag") {
                    withAnimation { model.open(bag) }
                }
            }
        } header: {
            Text("Stock")
        }
        .animation(.snappy, value: bag.stock)
    }

    private func figures(_ bag: Bag) -> some View {
        HStack(spacing: 10) {
            figure("THC", bag.thc?.label ?? "–", prominent: true)
            figure("CBD", bag.cbd?.label ?? "–")
            if let units = bag.unitCount, units > 1, let per = bag.gramsPerUnit {
                figure(String(localized: "Prerolls"), "\(units) × " + per.gramsLabel)
            } else {
                figure(String(localized: "Weight"), bag.grams?.gramsLabel ?? "–")
            }
            if let type = bag.strainType { figure(String(localized: "Type"), type.label) }
        }
    }

    private func figure(_ title: String, _ value: String, prominent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(prominent ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            Text(value)
                .font(.title3.weight(.semibold))
                .fontDesign(.rounded)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(tint: prominent ? Theme.leafMid : nil, padding: 12)
        .accessibilityElement(children: .combine)
    }

    private func row(_ title: String, _ value: String?) -> some View {
        LabeledContent(title, value: value ?? String(localized: "Not recorded"))
            .foregroundStyle(value == nil ? .secondary : .primary)
    }

    @ViewBuilder private func code(_ title: String, _ value: String?) -> some View {
        if let value {
            LabeledContent(title) {
                Text(value)
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
            }
            .contextMenu {
                Button("Copy", systemImage: "doc.on.doc") { UIPasteboard.copyPrivately(value) }
            }
        }
    }
}

struct PhotoViewer: View {
    let name: String?
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var steadyScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var steadyOffset: CGSize = .zero

    var body: some View {
        NavigationStack {
            BagPhoto(name: name, thumbnail: false, contentMode: .fit)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnifyGesture()
                        .onChanged { scale = max(1, steadyScale * $0.magnification) }
                        .onEnded { _ in
                            steadyScale = scale
                            if scale == 1 { withAnimation(.snappy) { reset() } }
                        }
                        .simultaneously(with: DragGesture()
                            .onChanged { value in
                                // Panning only means something when zoomed in.
                                guard scale > 1 else { return }
                                offset = CGSize(width: steadyOffset.width + value.translation.width,
                                                height: steadyOffset.height + value.translation.height)
                            }
                            .onEnded { _ in steadyOffset = offset })
                )
                .onTapGesture(count: 2) {
                    withAnimation(.snappy) {
                        if scale > 1 { reset() } else { scale = 2.5; steadyScale = 2.5 }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .background(.black)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", systemImage: "xmark") { dismiss() }
                    }
                }
        }
    }

    private func reset() {
        scale = 1
        steadyScale = 1
        offset = .zero
        steadyOffset = .zero
    }
}
