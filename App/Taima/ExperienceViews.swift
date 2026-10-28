import SwiftUI
import TaimaCore

/// Five stars showing a score out of 10, in half stars.
struct HalfStars: View {
    let score: Double
    var size: Font = .subheadline

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                let value = score / 2 - Double(index)
                Image(systemName: value >= 1 ? "star.fill" : value >= 0.5 ? "star.leadinghalf.filled" : "star")
                    .foregroundStyle(value >= 0.5 ? AnyShapeStyle(Theme.leafMid) : AnyShapeStyle(.tertiary))
            }
        }
        .font(size)
        .accessibilityElement()
        .accessibilityLabel("\(score.formatted(.number.precision(.fractionLength(0...1)))) out of 10")
    }
}

/// A score out of 10 in half steps: drag or tap the stars, or step by 0.5.
struct ScoreControl: View {
    @Binding var score: Double?
    @State private var width: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(score.map { $0.formatted(.number.precision(.fractionLength(0...1))) } ?? "–")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: score ?? 0))
                Text("/ 10").font(.headline).foregroundStyle(.secondary)
                Spacer()
                if score != nil {
                    Button("Clear score", systemImage: "xmark.circle.fill") {
                        withAnimation(.snappy) { score = nil }
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
                }
                Stepper("Score", onIncrement: { step(0.5) }, onDecrement: { step(-0.5) })
                    .labelsHidden()
            }
            HalfStars(score: score ?? 0, size: .title)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = max($0, 1) }
                .contentShape(.rect)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let fraction = min(1, max(0, value.location.x / width))
                            // Half a star per step; the very left edge clears.
                            let snapped = (fraction * 10 * 2).rounded(.up) / 2
                            withAnimation(.snappy(duration: 0.15)) { score = max(0.5, snapped) }
                        }
                )
                .accessibilityElement()
                .accessibilityLabel("Score")
                .accessibilityValue(score.map { "\($0.formatted()) out of 10" } ?? "Not rated")
                .accessibilityAdjustableAction { direction in
                    step(direction == .increment ? 0.5 : -0.5)
                }
        }
        .sensoryFeedback(.selection, trigger: score)
    }

    private func step(_ delta: Double) {
        withAnimation(.snappy) { score = min(10, max(0.5, (score ?? 5) + delta)) }
    }
}

/// Wraps chips onto as many lines as they need.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    /// A chip never measures wider than the row, so long tags wrap inside it.
    private func size(of subview: LayoutSubview, width: CGFloat) -> CGSize {
        let natural = subview.sizeThatFits(.unspecified)
        guard natural.width > width, width.isFinite else { return natural }
        return subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = size(of: subviews[index], width: bounds.width)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [(indices: [Int], width: CGFloat, height: CGFloat)] {
        var rows: [(indices: [Int], width: CGFloat, height: CGFloat)] = []
        var current: (indices: [Int], width: CGFloat, height: CGFloat) = ([], 0, 0)
        for index in subviews.indices {
            let size = size(of: subviews[index], width: width)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = ([index], size.width, size.height)
            } else {
                current = (current.indices + [index], needed, max(current.height, size.height))
            }
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

/// Pick tags from suggestions or type your own.
struct TagPicker: View {
    let suggestions: [String]
    @Binding var selection: [String]
    var hue: Color = Theme.leafMid
    @State private var custom = ""

    private var options: [String] {
        let extra = selection.filter { tag in !suggestions.contains { $0.caseInsensitiveCompare(tag) == .orderedSame } }
        return suggestions + extra
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FlowLayout(spacing: 8) {
                ForEach(options, id: \.self) { tag in
                    let isOn = selection.contains { $0.caseInsensitiveCompare(tag) == .orderedSame }
                    Button {
                        withAnimation(.snappy(duration: 0.2)) { toggle(tag) }
                    } label: {
                        HStack(spacing: 4) {
                            if isOn { Image(systemName: "checkmark").font(.caption2.weight(.bold)) }
                            Text(tag)
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .foregroundStyle(.primary)
                        .background { SelectableChipBackground(isOn: isOn, hue: hue) }
                        .frame(minHeight: 44)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            HStack {
                TextField("Add your own", text: $custom)
                    .textInputAutocapitalization(.sentences)
                    .onSubmit(addCustom)
                if !custom.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button("Add", action: addCustom).buttonStyle(.borderless)
                }
            }
            .font(.subheadline)
        }
        .sensoryFeedback(.selection, trigger: selection.count)
    }

    private func toggle(_ tag: String) {
        if let index = selection.firstIndex(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) {
            selection.remove(at: index)
        } else {
            selection.append(tag)
        }
    }

    private func addCustom() {
        let tag = custom.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty else { return }
        if !selection.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) {
            withAnimation(.snappy) { selection.append(tag) }
        }
        custom = ""
    }
}

/// Read-only tags, for details and strains.
struct TagCloud: View {
    let tags: [(String, Int?)]
    var hue: Color = Theme.leafMid

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(tags, id: \.0) { tag, count in
                HStack(spacing: 4) {
                    Text(tag)
                    if let count, count > 1 {
                        Text("\(count)").fontWeight(.semibold).foregroundStyle(hue)
                    }
                }
                .font(.subheadline)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(hue.opacity(0.13), in: .capsule)
            }
        }
    }
}
