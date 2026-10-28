import SwiftUI
import TaimaCore

/// Shows exactly what would be shared before anything leaves the phone.
struct SampleShareSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let sample: LabelSample

    private var issueURL: URL? {
        var components = URLComponents(string: "https://github.com/\(Published.repository)/issues/new")
        components?.queryItems = [
            URLQueryItem(name: "title", value: "Label sample: " + (sample.fields.first { $0.field == "name" }?.corrected ?? "correction")),
            URLQueryItem(name: "labels", value: "label-sample"),
            URLQueryItem(name: "body", value: "Shared from Taima to improve label reading.\n\n```json\n\(sample.json)\n```")
        ]
        return components?.url
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("You corrected what Taima read. Sharing this sample helps label reading improve for everyone. This is everything it contains:")
                        .font(.subheadline)
                }
                Section("Corrections") {
                    ForEach(sample.fields, id: \.field) { field in
                        HStack {
                            Text(field.field).foregroundStyle(.secondary)
                            Spacer()
                            Text(field.read ?? "–").strikethrough().foregroundStyle(.tertiary)
                            Image(systemName: "arrow.right").font(.caption).foregroundStyle(.tertiary)
                            Text(field.corrected ?? "–").fontWeight(.semibold)
                        }
                        .font(.subheadline)
                    }
                }
                Section {
                    Text(sample.text).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                } header: {
                    Text("Text read from the label")
                } footer: {
                    Text("Product codes and barcodes are removed. No photo, price, shop, note or date of yours is included. Nothing is sent unless you choose below.")
                }
                Section {
                    if let issueURL {
                        Button("Open as a GitHub issue", systemImage: "arrow.up.forward.app") {
                            openURL(issueURL)
                            dismiss()
                        }
                    }
                    ShareLink(item: sample.json) {
                        Label("Share another way", systemImage: "square.and.arrow.up")
                    }
                } footer: {
                    Text("A GitHub issue is public and needs a GitHub account; you see it before it's posted.")
                }
            }
            .navigationTitle("Share a label sample?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Not now", role: .cancel) { dismiss() } }
            }
        }
    }
}

/// Settings for learning on the phone and optional sharing.
struct LearningSettings: View {
    @Environment(AppModel.self) private var model
    @State private var memory = CorrectionMemory()

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                Toggle("Learn from my corrections", isOn: $model.learningEnabled)
            } footer: {
                Text("When you fix a name Taima misread, it remembers the fix on this iPhone and applies it to later scans. Nothing is sent.")
            }
            if !memory.words.isEmpty {
                Section("Learned on this iPhone") {
                    ForEach(memory.words.sorted { $0.key < $1.key }, id: \.key) { wrong, right in
                        LabeledContent(wrong, value: right)
                    }
                    .onDelete { offsets in
                        let keys = memory.words.sorted { $0.key < $1.key }.map(\.key)
                        for index in offsets { memory.forget(keys[index]) }
                        model.correctionMemory = memory
                    }
                }
            }
            Section {
                Toggle("Offer to share label samples", isOn: $model.sharingSamples)
            } footer: {
                Text("Off by default. When on, after you correct a new bag Taima shows you the sample (the text it read and your corrections, without codes, photos or anything personal) and asks first. Shared samples become test cases, and better reading reaches everyone through updates.")
            }
        }
        .navigationTitle("Label reading")
        .onAppear { memory = model.correctionMemory }
    }
}
