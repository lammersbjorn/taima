import PhotosUI
import SwiftUI
import TaimaCore

/// Writes a note at a moment, with an optional photo.
struct AddNoteSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let bag: Bag
    @State private var text = ""
    @State private var date = Date.now
    @State private var image: UIImage?
    @State private var pickedItem: PhotosPickerItem?
    @State private var saving = false
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("How is it going?", text: $text, axis: .vertical)
                        .lineLimit(3...10)
                        .focused($focused)
                    DatePicker("Time", selection: $date, in: ...Date.now.addingTimeInterval(60))
                } footer: {
                    if let since = sinceLastUse {
                        Text(since)
                    }
                }
                Section {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .clipShape(.rect(cornerRadius: Theme.mediaRadius))
                            .listRowInsets(EdgeInsets())
                        Button("Remove photo", systemImage: "trash", role: .destructive) { withAnimation { self.image = nil } }
                            .tint(.red)
                    } else {
                        if Camera.isAvailable {
                            Button("Take a photo", systemImage: "camera") {
                                focused = false
                                Camera.capture { captured in withAnimation { image = captured } }
                            }
                        }
                        PhotosPicker(selection: $pickedItem, matching: .images) {
                            Label("Choose a photo", systemImage: "photo")
                        }
                    }
                } header: {
                    Text("Photo")
                }
            }
            .navigationTitle(bag.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", role: .cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") {
                        saving = true
                        Task {
                            await model.addNote(text.trimmingCharacters(in: .whitespacesAndNewlines), at: date, image: image, to: bag)
                            dismiss()
                        }
                    }
                    .solidGlass()
                    .disabled(saving || (text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && image == nil))
                }
            }
            .onChange(of: pickedItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let picked = UIImage(data: data) {
                        withAnimation { image = picked }
                    }
                    pickedItem = nil
                }
            }
            .onAppear { focused = true }
        }
        // Swiping down would lose what was written.
        .interactiveDismissDisabled(!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || image != nil)
    }

    private var sinceLastUse: String? {
        guard let last = bag.usage.filter({ $0.date <= date }).map(\.date).max(),
              date.timeIntervalSince(last) < 12 * 3600 else { return nil }
        return String(localized: "\(TimelineEntry.offset(from: last, to: date)) after your last session.")
    }
}

/// Sessions and notes in one list, newest first.
enum TimelineEntry: Identifiable {
    case session(UsageEntry)
    case note(TimedNote)

    var id: UUID {
        switch self {
        case .session(let entry): entry.id
        case .note(let note): note.id
        }
    }

    var date: Date {
        switch self {
        case .session(let entry): entry.date
        case .note(let note): note.date
        }
    }

    static func entries(for bag: Bag) -> [TimelineEntry] {
        (bag.usage.map(TimelineEntry.session) + bag.noteLog.map(TimelineEntry.note)).sorted { $0.date > $1.date }
    }

    /// "40 min" or "2 hr, 5 min", in the person's language.
    static func offset(from start: Date, to end: Date) -> String {
        let minutes = max(0, Int(end.timeIntervalSince(start) / 60))
        return Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}

/// The timeline section on a bag's detail page.
struct BagTimelineSection: View {
    @Environment(AppModel.self) private var model
    let bag: Bag
    let addNote: () -> Void
    @State private var viewing: String?
    @State private var editing: UsageEntry?

    var body: some View {
        let entries = TimelineEntry.entries(for: bag)
        Section {
            Button("Add a note", systemImage: "note.text.badge.plus", action: addNote)
            ForEach(entries.prefix(30)) { entry in
                switch entry {
                case .session(let session):
                    Button { editing = session } label: {
                    HStack(spacing: 10) {
                        Image(systemName: session.method?.symbol ?? "minus.circle")
                            .foregroundStyle(Theme.leafMid)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.grams.formatted(.number.precision(.fractionLength(0...2))) + " g" + (session.method.map { " · \($0.label)" } ?? ""))
                                .font(.subheadline.weight(.medium))
                            if let note = session.note { Text(note).font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        Text(session.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                    }
                    .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Edit this session")
                    .swipeActions {
                        Button("Remove", systemImage: "arrow.uturn.backward", role: .destructive) { model.undoUse(session, in: bag) }
                    }
                case .note(let note):
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "note.text").foregroundStyle(Theme.leafDeep).frame(width: 22)
                        VStack(alignment: .leading, spacing: 4) {
                            if !note.text.isEmpty { Text(note.text).font(.subheadline) }
                            HStack(spacing: 4) {
                                Text(note.date.formatted(date: .abbreviated, time: .shortened))
                                if let offset = offset(for: note) { Text("· \(offset) after a session") }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        if let photo = note.photoName {
                            Button { viewing = photo } label: {
                                BagPhoto(name: photo)
                                    .frame(width: 52, height: 52)
                                    .clipShape(.rect(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Show note photo")
                        }
                    }
                    .swipeActions {
                        Button("Delete", systemImage: "trash", role: .destructive) { model.deleteNote(note, from: bag) }
                    }
                }
            }
        } header: {
            Text("Timeline")
        } footer: {
            if entries.isEmpty { Text("Notes and sessions for this bag appear here, newest first.") }
        }
        .fullScreenCover(item: $viewing) { name in PhotoViewer(name: name) }
        .sheet(item: $editing) { entry in SessionEditSheet(bag: bag, entry: entry) }
    }

    private func offset(for note: TimedNote) -> String? {
        guard let last = bag.usage.filter({ $0.date <= note.date }).map(\.date).max(),
              note.date.timeIntervalSince(last) < 12 * 3600 else { return nil }
        return TimelineEntry.offset(from: last, to: note.date)
    }
}
