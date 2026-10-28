import SwiftUI
import TaimaCore

struct MilestoneToast: View {
    let milestone: Milestone

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: milestone.symbol)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Theme.hero, in: .circle)
                .symbolEffect(.bounce, value: milestone.id)
            VStack(alignment: .leading, spacing: 1) {
                Text("Milestone earned").font(.caption).foregroundStyle(.secondary)
                Text(milestone.title).font(.subheadline.weight(.semibold))
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 16)
        .padding(.vertical, 8)
        .glassEffect(.regular.tint(Theme.leafMid.opacity(0.2)), in: .capsule)
        .sensoryFeedback(.success, trigger: milestone.id)
        .accessibilityElement(children: .combine)
    }
}

/// Earned badges in colour, the rest grey with their progress. Tapping a
/// badge explains what earns it and where to do that.
struct MilestonesCard: View {
    let milestones: [Milestone]
    @State private var selected: Milestone.ID?
    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 12)]

    var body: some View {
        let earned = milestones.filter(\.achieved).count
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Milestones").font(.headline)
                    Spacer()
                    Text("\(earned) of \(milestones.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text("Tap a badge to see how to earn it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: columns, spacing: 22) {
                ForEach(milestones) { milestone in
                    Button {
                        selected = milestone.id
                    } label: {
                        badge(milestone)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: Binding(
                        get: { selected == milestone.id },
                        set: { if !$0, selected == milestone.id { selected = nil } }
                    )) {
                        MilestoneDetail(milestone: milestone)
                            .presentationCompactAdaptation(.popover)
                    }
                    .accessibilityLabel("\(milestone.title). \(milestone.detail) " + (milestone.achieved ? String(localized: "Earned") : String(localized: "\(milestone.current) of \(milestone.target)")))
                    .accessibilityHint("Shows how to earn it")
                }
            }
        }
        .glassCard()
    }

    private func badge(_ milestone: Milestone) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Theme.leafMid.opacity(0.15), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: milestone.progress)
                    .stroke(milestone.achieved ? Theme.leafMid : Theme.leafMid.opacity(0.5), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: milestone.symbol)
                    .font(.title3)
                    .foregroundStyle(milestone.achieved ? AnyShapeStyle(Theme.leafMid) : AnyShapeStyle(.tertiary))
            }
            .frame(width: 52, height: 52)
            Text(milestone.title)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxHeight: .infinity, alignment: .top)
                .foregroundStyle(milestone.achieved ? .primary : .secondary)
            Text(milestone.achieved ? String(localized: "Earned") : "\(milestone.current)/\(milestone.target)")
                .font(.caption)
                .foregroundStyle(milestone.achieved ? AnyShapeStyle(Theme.leafMid) : AnyShapeStyle(.secondary))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .contentShape(.rect)
    }
}

/// What a milestone asks for, where to do it and how far along you are.
private struct MilestoneDetail: View {
    let milestone: Milestone

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: milestone.symbol)
                    .font(.title3)
                    .foregroundStyle(milestone.achieved ? AnyShapeStyle(Theme.leafMid) : AnyShapeStyle(.secondary))
                    .frame(width: 32)
                Text(milestone.title).font(.headline)
            }
            Text(milestone.detail).font(.subheadline.weight(.medium))
            Text(milestone.hint)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if milestone.achieved {
                Label("Earned", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.leafMid)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: milestone.progress).tint(Theme.leafMid)
                    Text("\(milestone.current) of \(milestone.target) · \(milestone.remaining) to go")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .padding(18)
        .frame(width: 300, alignment: .leading)
    }
}
