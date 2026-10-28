import PhotosUI
import SwiftUI
import TaimaCore

struct BagEditorView: View {
    @Environment(AppModel.self) private var model
    @State private var draft: BagDraft
    @State private var thcText: String
    @State private var cbdText: String
    @State private var gramsText: String
    @State private var priceText: String
    @State private var confirmingDiscard = false
    @State private var confirmingDropEdits = false
    @State private var rescanning = false
    @State private var readingBack = false
    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var libraryTarget: PhotoTarget?
    @State private var pickerTarget: PhotoTarget?
    @State private var rotateScanning = false
    @State private var remainingText: String
    @FocusState private var focused: Bool

    init(draft: BagDraft) {
        _draft = State(initialValue: draft)
        _thcText = State(initialValue: Self.text(draft.bag.thc))
        _cbdText = State(initialValue: Self.text(draft.bag.cbd))
        _gramsText = State(initialValue: draft.bag.grams.map { Self.number($0, digits: 2) } ?? "")
        _priceText = State(initialValue: draft.bag.priceEuros.map {
            // Cents always show two digits: 7,50, not 7,5.
            $0.rounded() == $0 ? Self.number($0) : $0.formatted(.number.precision(.fractionLength(2)).grouping(.never))
        } ?? "")
        _remainingText = State(initialValue: draft.bag.stock == .open ? Self.number(draft.bag.remaining, digits: 2) : "")
    }

    private var queueRemaining: Int { max(model.drafts.count - 1, 0) }

    var body: some View {
        NavigationStack {
            Form {
                if draft.bag.mainPhoto != nil {
                    Section {
                        BagPhoto(name: draft.bag.mainPhoto, thumbnail: false)
                            .frame(height: 220)
                            .clipShape(.rect(cornerRadius: Theme.mediaRadius))
                            .overlay(alignment: .bottomTrailing) {
                                if draft.bag.photoName != nil {
                                    Button("Read again", systemImage: "text.viewfinder") { rereadLabel() }
                                        .buttonStyle(.glass)
                                        .disabled(rescanning)
                                        .padding(10)
                                }
                            }
                            .listRowInsets(EdgeInsets())
                    } footer: {
                        scanSummary
                    }
                }
                if let duplicate = model.duplicate(of: draft.bag) {
                    Section {
                        Label("You already saved this bag as “\(duplicate.displayName)”. The product ID matches.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.subheadline)
                    }
                }
                labelSection
                stockSection
                backSection
                datesSection
                personalSection
                experienceSection
                codesSection
            }
            .scrollDismissesKeyboard(.interactively)
            .fullScreenCover(isPresented: $rotateScanning) {
                RotateScanView { reading, image in
                    Task {
                        commitNumbers()
                        let updated = await model.applyingFused(reading, image: image, to: draft)
                        withAnimation(.snappy) {
                            draft = updated
                            thcText = Self.text(updated.bag.thc)
                            cbdText = Self.text(updated.bag.cbd)
                            gramsText = updated.bag.grams.map { Self.number($0, digits: 2) } ?? ""
                        }
                    }
                }
            }
            .navigationTitle(draft.isNew ? String(localized: "New bag") : String(localized: "Edit bag"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(draft.isNew ? String(localized: "Discard") : String(localized: "Cancel"), role: .cancel) {
                        if draft.isNew {
                            confirmingDiscard = true
                        } else if hasEdits {
                            confirmingDropEdits = true
                        } else {
                            model.finishDraft(draft, saved: false)
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(queueRemaining > 0 ? String(localized: "Save, next") : String(localized: "Save"), systemImage: "checkmark") {
                        focused = false
                        commitNumbers()
                        model.finishDraft(draft, saved: true)
                    }
                    .solidGlass()
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focused = false }
                }
            }
            .alert("Not saved", isPresented: Binding(
                get: { model.problem != nil },
                set: { if !$0 { model.problem = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.problem ?? "")
            }
            #if DEBUG
            .task {
                // Simulator check of the review queue: save each draft through the real sheet.
                guard ProcessInfo.processInfo.environment["TAIMA_UI_SAVE"] == "1" else { return }
                try? await Task.sleep(for: .seconds(1))
                commitNumbers()
                model.finishDraft(draft, saved: true)
            }
            #endif
            .confirmationDialog("Discard your changes?", isPresented: $confirmingDropEdits, titleVisibility: .visible) {
                Button("Discard changes", role: .destructive) { model.finishDraft(draft, saved: false) }
                Button("Keep editing", role: .cancel) {}
            }
            .confirmationDialog("Discard this bag?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button("Discard", role: .destructive) { model.finishDraft(draft, saved: false) }
            } message: {
                Text("The photo and the values read from it are removed.")
            }
        }
    }

    @ViewBuilder private var scanSummary: some View {
        let count = draft.detected.count
        HStack(spacing: 6) {
            if rescanning {
                ProgressView().controlSize(.mini)
                Text("Reading label…")
            } else if draft.isNew || count > 0 {
                DetectedMark()
                let unsure = draft.doubtful.intersection(draft.detected).count
                Text(count == 0 ? String(localized: "Nothing could be read. Fill in what you see.")
                     : unsure > 0 ? String(localized: "\(count) values read; \(unsure) marked in orange need a closer look.")
                     : String(localized: "\(count) values read from the label. Check them before saving."))
            }
            Spacer()

        }
        .font(.footnote)
        .padding(.top, 4)
    }

    private func rereadLabel() {
        Task {
            rescanning = true
            let fresh = await model.rescan(draft)
            draft = fresh
            thcText = Self.text(fresh.bag.thc)
            cbdText = Self.text(fresh.bag.cbd)
            gramsText = fresh.bag.grams.map { Self.number($0, digits: 2) } ?? ""
            rescanning = false
        }
    }

    // MARK: - Sections

    private var labelSection: some View {
        Section("Label") {
            field(String(localized: "Product"), .form) {
                Picker("Product", selection: tracked(\.form, .form)) {
                    ForEach(ProductForm.allCases) { form in
                        Label(form.label, systemImage: form.symbol).tag(form)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }
            if draft.bag.form == .preroll {
                field(String(localized: "Prerolls in pack"), .unitCount) {
                    Stepper(value: Binding(
                        get: { draft.bag.unitCount ?? 1 },
                        set: { draft.bag.unitCount = $0; draft.detected.remove(.unitCount) }
                    ), in: 1...50) {
                        Text("\(draft.bag.unitCount ?? 1)" + (draft.bag.gramsPerUnit.map { String(localized: " × \($0.formatted(.number.precision(.fractionLength(0...2)))) g") } ?? ""))
                            .monospacedDigit()
                    }
                }
            }
            field(String(localized: "Name"), .name) {
                TextField("Strain name", text: tracked(\.name, .name))
                    .textInputAutocapitalization(.words)
                    .font(.headline)
            }
            field(String(localized: "Grower"), .producer) {
                HStack {
                    TextField("Grower or brand", text: Binding(
                        get: { draft.bag.producer ?? "" },
                        set: { draft.bag.producer = $0; draft.detected.remove(.producer) }
                    ))
                    .textInputAutocapitalization(.words)
                    if !model.growerSuggestions.isEmpty {
                        Menu {
                            ForEach(model.growerSuggestions, id: \.self) { name in
                                Button(name) { draft.bag.producer = name; draft.detected.remove(.producer) }
                            }
                        } label: {
                            Image(systemName: "chevron.up.chevron.down")
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(.rect)
                                .accessibilityLabel("Choose a known grower")
                        }
                    }
                }
            }
            field(String(localized: "Type"), .strainType) {
                Picker("Type", selection: tracked(\.strainType, .strainType)) {
                    Text("Not set").tag(StrainType?.none)
                    ForEach(StrainType.allCases) { Text($0.label).tag(StrainType?.some($0)) }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }
            HStack(spacing: 12) {
                numberField("THC %", text: $thcText, field: .thc, keyboard: .numbersAndPunctuation)
                numberField("CBD %", text: $cbdText, field: .cbd, keyboard: .numbersAndPunctuation)
                numberField(String(localized: "Grams"), text: $gramsText, field: .grams, keyboard: .decimalPad)
            }
        }
    }

    private var stockSection: some View {
        Section {
            Picker("Stock", selection: Binding(
                get: { draft.bag.stock },
                set: { newValue in
                    withAnimation(.snappy) {
                        draft.bag.stock = newValue
                        if newValue == .open {
                            if draft.bag.remainingGrams == nil || remainingText.isEmpty {
                                remainingText = Self.number(draft.bag.remainingGrams ?? draft.bag.grams ?? 0, digits: 2)
                            }
                        } else {
                            draft.bag.remainingGrams = newValue == .full ? draft.bag.grams : 0
                        }
                    }
                    if draft.isNew { model.defaultStock = newValue }
                }
            )) {
                ForEach(StockState.allCases) { state in
                    Text(state.label).tag(state)
                }
            }
            .pickerStyle(.segmented)
            if draft.bag.stock == .open {
                LabeledContent("Grams left") {
                    TextField("0", text: $remainingText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focused)
                        .onChange(of: remainingText) { commitNumbers() }
                }
            }
        } header: {
            Text("Stock")
        } footer: {
            Text(stockFooter)
        }
    }

    private var stockFooter: String {
        switch draft.bag.stock {
        case .full: String(localized: "Counts toward your stash. Open it from the Stash tab when you start on it.")
        case .open: String(localized: "Log what you use from the Stash tab, a widget or the Live Activity.")
        case .empty: String(localized: "Kept in your collection only.")
        }
    }

    private enum PhotoTarget: Identifiable {
        case front, back, flower
        var id: Self { self }
    }

    private var backSection: some View {
        Section {
            if !draft.bag.photoNames.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(draft.bag.photoNames, id: \.self) { name in
                            photoTile(name)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            if readingBack {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Reading the photo…").foregroundStyle(.secondary)
                }
            } else {
                Menu {
                    Section("Photo of the flower") {
                        if Camera.isAvailable {
                            Button("Take photo", systemImage: "camera") { takePhoto(for: .flower) }
                        }
                        Button("Choose photos", systemImage: "photo.on.rectangle") { libraryTarget = .flower }
                    }
                    Section("Back of the bag") {
                        if Camera.isAvailable {
                            Button("Scan back", systemImage: "camera.viewfinder") { takePhoto(for: .back) }
                        }
                        Button("Choose back photo", systemImage: "photo") { libraryTarget = .back }
                    }
                    Section("Label photo") {
                        if Camera.isAvailable {
                            Button("Rotate to scan the label", systemImage: "arrow.triangle.2.circlepath.camera") { rotateScanning = true }
                            Button("Retake label", systemImage: "camera") { takePhoto(for: .front) }
                        }
                        Button("Choose label photo", systemImage: "photo") { libraryTarget = .front }
                    }
                } label: {
                    Label("Add or change photos", systemImage: "plus.circle.fill")
                }
            }
        } header: {
            Text("Photos")
        } footer: {
            Text("The starred photo shows in your collection. Hold a photo to make it the main one, replace it or remove it.")
        }
        .photosPicker(isPresented: Binding(get: { libraryTarget != nil }, set: { if !$0 { pickerTarget = libraryTarget; libraryTarget = nil } }),
                      selection: $pickedItems, maxSelectionCount: libraryTarget == .flower ? 10 : 1, matching: .images)
        .onChange(of: pickedItems) { _, items in
            guard !items.isEmpty, let target = pickerTarget ?? libraryTarget else { return }
            pickedItems = []
            Task {
                for item in items {
                    guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else { continue }
                    await apply(image, to: target)
                }
            }
        }
    }

    private func photoTile(_ name: String) -> some View {
        let role = name == draft.bag.photoName ? String(localized: "Label") : name == draft.bag.backPhotoName ? String(localized: "Back") : String(localized: "Flower")
        let isMain = draft.bag.mainPhoto == name
        return Menu {
            if !isMain {
                Button("Use as main photo", systemImage: "star") {
                    withAnimation(.snappy) { draft.bag.coverPhotoName = name }
                }
            }
            if name == draft.bag.photoName {
                Button("Replace label photo", systemImage: "photo") { libraryTarget = .front }
            } else if name == draft.bag.backPhotoName {
                Button("Replace back photo", systemImage: "photo") { libraryTarget = .back }
            }
            Button("Remove", systemImage: "trash", role: .destructive) {
                withAnimation(.snappy) { draft = model.removingPhoto(name, from: draft) }
            }
            .tint(.red)
        } label: {
            VStack(spacing: 4) {
                BagPhoto(name: name)
                    .frame(width: 88, height: 88)
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay(alignment: .topTrailing) {
                        if isMain {
                            Image(systemName: "star.fill")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(5)
                                .background(Theme.solid, in: .circle)
                                .padding(4)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(isMain ? Color.accentColor : .clear, lineWidth: 2)
                    }
                Text(role).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel("\(role) photo\(isMain ? String(localized: ", main photo") : "")")
    }

    private func takePhoto(for target: PhotoTarget) {
        Camera.capture { image in
            Task { await apply(image, to: target) }
        }
    }

    private func apply(_ image: UIImage, to target: PhotoTarget) async {
        commitNumbers()
        readingBack = true
        let updated: BagDraft
        switch target {
        case .front: updated = await model.replacingFront(image, in: draft)
        case .back: updated = await model.addingBack(image, to: draft)
        case .flower: updated = await model.addingFlowerPhoto(image, to: draft)
        }
        withAnimation(.snappy) {
            draft = updated
            thcText = Self.text(updated.bag.thc)
            cbdText = Self.text(updated.bag.cbd)
            gramsText = updated.bag.grams.map { Self.number($0, digits: 2) } ?? ""
            readingBack = false
        }
    }

    private var datesSection: some View {
        Section {
            OptionalDateRow(title: String(localized: "Harvested"), date: tracked(\.harvestedOn, .harvestedOn), detected: draft.detected.contains(.harvestedOn))
            OptionalDateRow(title: String(localized: "Packed"), date: tracked(\.packedOn, .packedOn), detected: draft.detected.contains(.packedOn))
            if draft.bag.bestBeforeOn != nil || draft.detected.contains(.bestBeforeOn) {
                OptionalDateRow(title: String(localized: "Best before"), date: tracked(\.bestBeforeOn, .bestBeforeOn), detected: draft.detected.contains(.bestBeforeOn))
            }
            DatePicker("Collected", selection: $draft.bag.collectedOn, in: ...Date.now.addingTimeInterval(86_400), displayedComponents: .date)
        } header: {
            Text("Dates")
        } footer: {
            if let days = draft.bag.cureDays {
                Text("\(days) days from harvest to packing.")
            }
        }
    }

    private var personalSection: some View {
        Section("Yours") {
            ScoreControl(score: $draft.bag.rating10)
            Picker("Would buy again", selection: $draft.bag.wouldBuyAgain) {
                Text("Not decided").tag(Bool?.none)
                Text("Yes").tag(Bool?.some(true))
                Text("No").tag(Bool?.some(false))
            }
            HStack {
                TextField("Bought at (coffeeshop)", text: Binding(
                    get: { draft.bag.shop ?? "" },
                    set: { draft.bag.shop = $0.isEmpty ? nil : $0 }
                ))
                .textInputAutocapitalization(.words)
                .focused($focused)
                if !model.shopSuggestions.isEmpty {
                    Menu {
                        ForEach(model.shopSuggestions, id: \.name) { shop in
                            Button(shop.city.map { "\(shop.name), \($0)" } ?? shop.name) {
                                draft.bag.shop = shop.name
                                draft.bag.shopCity = shop.city
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.up.chevron.down")
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(.rect)
                            .accessibilityLabel("Choose a shop you've used")
                    }
                }
            }
            TextField("Town", text: Binding(
                get: { draft.bag.shopCity ?? "" },
                set: { draft.bag.shopCity = $0.isEmpty ? nil : $0 }
            ))
            .textInputAutocapitalization(.words)
            .focused($focused)
            LabeledContent("Price") {
                TextField("€", text: $priceText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($focused)
                    .onChange(of: priceText) { commitNumbers() }
            }
            TextField("Notes", text: $draft.bag.notes, axis: .vertical)
                .lineLimit(3...8)
                .focused($focused)
        }
    }

    private var experienceSection: some View {
        Group {
            Section {
                TagPicker(suggestions: ExperienceTags.positive, selection: $draft.bag.positiveEffects)
            } header: {
                Text("Effects")
            }
            Section {
                TagPicker(suggestions: ExperienceTags.negative, selection: $draft.bag.negativeEffects, hue: .orange)
            } header: {
                Text("Downsides")
            }
            Section {
                TagPicker(suggestions: ExperienceTags.flavors, selection: $draft.bag.flavorTags, hue: .teal)
            } header: {
                Text("Taste and smell")
            } footer: {
                Text("Your own notes. Insights in Stats are built from them.")
            }
        }
    }

    private var codesSection: some View {
        Section {
            codeField(String(localized: "Product ID"), value: tracked(\.productID, .productID), field: .productID)
            codeField("SKU", value: tracked(\.sku, .sku), field: .sku)
            codeField("EAN", value: tracked(\.ean, .ean), field: .ean)
            if let leaflet = draft.bag.leafletURL {
                SafeLinkButton(title: String(localized: "Package leaflet"), systemImage: "doc.text", address: leaflet)
            }
        } header: {
            Text("Codes")
        } footer: {
            Text("The product ID comes from the track-and-trace QR code and is used to spot duplicates.")
        }
    }

    // MARK: - Field helpers

    private func field<Content: View>(_ title: String, _ key: LabelField, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(title)
                if draft.detected.contains(key) {
                    if draft.doubtful.contains(key) { CheckMark() } else { DetectedMark() }
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            content()
                .focused($focused)
        }
    }

    private func numberField(_ title: String, text: Binding<String>, field key: LabelField, keyboard: UIKeyboardType) -> some View {
        field(title, key) {
            TextField("–", text: text)
                .keyboardType(keyboard)
                .font(.title3.weight(.semibold).monospacedDigit())
                .onChange(of: text.wrappedValue) {
                    let before = draft.bag
                    commitNumbers()
                    // Only a real edit clears the mark, not a rescan refilling the text.
                    if before != draft.bag { draft.detected.remove(key) }
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func codeField(_ title: String, value: Binding<String?>, field key: LabelField) -> some View {
        field(title, key) {
            TextField("Not set", text: Binding(
                get: { value.wrappedValue ?? "" },
                set: { value.wrappedValue = $0.isEmpty ? nil : $0 }
            ))
            .font(.footnote.monospaced())
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }
    }

    /// A binding that clears the "read from label" mark once the person edits it.
    private func tracked<Value>(_ path: WritableKeyPath<Bag, Value>, _ key: LabelField) -> Binding<Value> {
        Binding(
            get: { draft.bag[keyPath: path] },
            set: { draft.bag[keyPath: path] = $0; draft.detected.remove(key) }
        )
    }

    /// Whether Cancel would throw away anything typed or changed.
    private var hasEdits: Bool {
        guard let original = draft.original else { return false }
        func comparable(_ bag: Bag) -> Bag {
            var bag = bag
            if bag.stock != .open { bag.remainingGrams = nil }
            return bag
        }
        return comparable(committed(draft.bag)) != comparable(original)
    }

    private func commitNumbers() { draft.bag = committed(draft.bag) }

    /// The bag with the typed numbers applied.
    private func committed(_ input: Bag) -> Bag {
        var bag = input
        if thcText != Self.text(bag.thc) { bag.thc = Self.potency(thcText) }
        if cbdText != Self.text(bag.cbd) { bag.cbd = Self.potency(cbdText) }
        bag.grams = Self.decimal(gramsText)
        bag.priceEuros = Self.decimal(priceText)
        switch bag.stock {
        case .open: bag.remainingGrams = Self.decimal(remainingText).map { min($0, bag.grams ?? $0) }
        case .full: bag.remainingGrams = bag.grams
        case .empty: bag.remainingGrams = 0
        }
        return bag
    }

    // MARK: - Number text

    static func text(_ potency: Potency?) -> String {
        guard let potency else { return "" }
        return (potency.isUpperBound ? "<" : "") + number(potency.percent, digits: 2)
    }

    static func number(_ value: Double, digits: Int = 1) -> String {
        value.formatted(.number.precision(.fractionLength(0...digits)).grouping(.never))
    }

    static func decimal(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
            .filter { $0.isNumber || $0 == "." }
        return Double(cleaned)
    }

    static func potency(_ text: String) -> Potency? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let value = decimal(trimmed), value <= 100 else { return nil }
        return Potency(percent: value, isUpperBound: trimmed.hasPrefix("<"))
    }
}

struct OptionalDateRow: View {
    let title: String
    @Binding var date: Date?
    var detected = false

    var body: some View {
        if let value = date {
            HStack {
                DatePicker(selection: Binding(get: { value }, set: { date = $0 }), displayedComponents: .date) {
                    HStack(spacing: 4) {
                        Text(title)
                        if detected { DetectedMark() }
                    }
                }
                Button { date = nil } label: {
                    Image(systemName: "xmark.circle.fill")
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(.rect)
                }
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
                .accessibilityLabel("Clear \(title)")
            }
        } else {
            Button {
                date = Calendar.taima.startOfDay(for: .now).addingTimeInterval(12 * 3600)
            } label: {
                LabeledContent(title) {
                    Text("Add").foregroundStyle(.tint)
                }
            }
            .foregroundStyle(.primary)
        }
    }
}

