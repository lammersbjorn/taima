import SwiftUI
import TaimaCore

/// Re-reads older bags with the current label reader and offers what it
/// would add. Each bag's changes are accepted or skipped; nothing entered by
/// hand is overwritten.
struct EntryReviewView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var suggestions: [EntryReview.Suggestion] = []
    @State private var accepted: Set<UUID> = []
    @State private var progress: (done: Int, total: Int)?
    @State private var finished = false

    var body: some View {
        NavigationStack {
            List {
                if let progress {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressView(value: Double(progress.done), total: Double(max(progress.total, 1)))
                                .tint(Theme.leafMid)
                            Text("Reading label \(min(progress.done + 1, progress.total)) of \(progress.total)…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } else if finished && suggestions.isEmpty {
                    ContentUnavailableView {
                        Label("All up to date", systemImage: "checkmark.circle")
                    } description: {
                        Text("Re-reading your labels found nothing new to add.")
                    }
                    .listRowBackground(Color.clear)
                }
                ForEach(suggestions) { suggestion in
                    Section {
                        ForEach(suggestion.changes) { change in
                            HStack(alignment: .firstTextBaseline) {
                                Text(change.field).font(.subheadline).foregroundStyle(.secondary)
                                Spacer()
                                if let old = change.old {
                                    Text(old).strikethrough().foregroundStyle(.tertiary)
                                    Image(systemName: "arrow.right").font(.caption).foregroundStyle(.tertiary)
                                }
                                Text(change.new).fontWeight(.semibold).multilineTextAlignment(.trailing)
                            }
                            .font(.subheadline)
                            .accessibilityElement(children: .combine)
                        }
                    } header: {
                        Toggle(isOn: Binding(
                            get: { accepted.contains(suggestion.id) },
                            set: { if $0 { accepted.insert(suggestion.id) } else { accepted.remove(suggestion.id) } }
                        )) {
                            HStack(spacing: 10) {
                                BagPhoto(name: suggestion.original.mainPhoto)
                                    .frame(width: 34, height: 34)
                                    .clipShape(.rect(cornerRadius: 8))
                                Text(suggestion.original.displayName)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .textCase(nil)
                            }
                        }
                        .tint(Theme.solid)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(GlowBackground())
            .navigationTitle("Improve older entries")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Later", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(accepted.isEmpty ? String(localized: "Done") : String(localized: "Apply \(accepted.count)"), systemImage: "checkmark") {
                        model.applyReview(suggestions.filter { accepted.contains($0.id) })
                        dismiss()
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Theme.solid)
                    .disabled(progress != nil)
                }
            }
            .task { await run() }
        }
    }

    private func run() async {
        progress = (0, model.bags.count)
        let found = await model.reviewSuggestions { done, total in progress = (done, total) }
        guard !Task.isCancelled else { return }
        withAnimation(.snappy) {
            suggestions = found
            accepted = Set(found.map(\.id))
            progress = nil
            finished = true
        }
        model.markReviewed()
    }
}
