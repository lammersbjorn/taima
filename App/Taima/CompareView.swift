import SwiftUI
import TaimaCore

/// Picks the second bag for a comparison.
struct ComparePicker: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let first: Bag
    @State private var search = ""
    @State private var second: Bag?

    var body: some View {
        NavigationStack {
            let others = model.bags.filter { $0.id != first.id && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)) }
            List(others) { bag in
                Button { second = bag } label: { BagRow(bag: bag) }
                    .buttonStyle(.plain)
            }
            .searchable(text: $search, prompt: String(localized: "Find a bag"))
            .navigationTitle("Compare with")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", role: .cancel) { dismiss() } }
            }
            .navigationDestination(item: $second) { other in
                CompareView(left: first, right: other)
            }
        }
    }
}

/// Two bags side by side; the better value of each row is marked.
struct CompareView: View {
    let left: Bag
    let right: Bag

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    header(left)
                    header(right)
                }
                .appearLift()
                VStack(spacing: 0) {
                    row(String(localized: "Grower"), left.producer ?? "–", right.producer ?? "–")
                    row(String(localized: "Type"), left.strainType?.label ?? "–", right.strainType?.label ?? "–")
                    numeric("THC", left.thc?.percent, right.thc?.percent, higherIsBetter: true) { $0.formatted(.number.precision(.fractionLength(0...1))) + "%" }
                    row("CBD", left.cbd?.label ?? "–", right.cbd?.label ?? "–")
                    numeric(String(localized: "Weight"), left.grams, right.grams, higherIsBetter: nil) { $0.gramsLabel }
                    numeric(String(localized: "Your score"), left.rating10, right.rating10, higherIsBetter: true) { $0.formatted(.number.precision(.fractionLength(0...1))) + " / 10" }
                    numeric(String(localized: "Harvest to pack"), left.cureDays.map(Double.init), right.cureDays.map(Double.init), higherIsBetter: nil) { String(localized: "\(Int($0)) days") }
                    numeric(String(localized: "Per gram"), left.pricePerGram, right.pricePerGram, higherIsBetter: false) { $0.formatted(.currency(code: "EUR")) }
                    row(String(localized: "Packed"), left.packedOn?.formatted(date: .abbreviated, time: .omitted) ?? "–", right.packedOn?.formatted(date: .abbreviated, time: .omitted) ?? "–")
                }
                .glassCard(padding: 0)
                .appearLift(delay: 0.05)
                tags(String(localized: "Effects"), left.positiveEffects, right.positiveEffects, Theme.leafMid)
                tags(String(localized: "Downsides"), left.negativeEffects, right.negativeEffects, .orange)
                tags(String(localized: "Taste and smell"), left.flavorTags, right.flavorTags, .teal)
            }
            .padding()
        }
        .background(GlowBackground())
        .navigationTitle("Compare")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(_ bag: Bag) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            BagPhoto(name: bag.mainPhoto, thumbnail: false)
                .frame(height: 130)
                .frame(maxWidth: .infinity)
                .clipShape(.rect(cornerRadius: Theme.mediaRadius))
            Text(bag.displayName).font(.headline).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ title: String, _ a: String, _ b: String, marked: (Bool, Bool) = (false, false)) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            HStack {
                value(a, marked.0)
                value(b, marked.1)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .overlay(alignment: .bottom) { Divider().padding(.horizontal, 14) }
    }

    private func value(_ text: String, _ marked: Bool) -> some View {
        HStack(spacing: 4) {
            if marked { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.leafMid).font(.caption) }
            Text(text).font(.subheadline.weight(marked ? .semibold : .regular)).monospacedDigit().lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }

    /// `higherIsBetter` nil means neither side is better, only different.
    private func numeric(_ title: String, _ a: Double?, _ b: Double?, higherIsBetter: Bool?, format: (Double) -> String) -> some View {
        var marks = (false, false)
        if let higherIsBetter, let a, let b, a != b {
            marks = (a > b) == higherIsBetter ? (true, false) : (false, true)
        }
        return row(title, a.map(format) ?? "–", b.map(format) ?? "–", marked: marks)
    }

    @ViewBuilder private func tags(_ title: String, _ a: [String], _ b: [String], _ hue: Color) -> some View {
        if !(a.isEmpty && b.isEmpty) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.headline)
                HStack(alignment: .top, spacing: 12) {
                    TagCloud(tags: a.map { ($0, nil) }, hue: hue).frame(maxWidth: .infinity, alignment: .leading)
                    TagCloud(tags: b.map { ($0, nil) }, hue: hue).frame(maxWidth: .infinity, alignment: .leading)
                }
                let shared = Set(a.map { $0.lowercased() }).intersection(b.map { $0.lowercased() })
                if !shared.isEmpty {
                    Text("Both: \(shared.sorted().map { ExperienceTags.label(for: $0) }.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .glassCard()
        }
    }
}
