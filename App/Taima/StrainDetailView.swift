import Charts
import SwiftUI
import TaimaCore

/// Every bag of one strain together.
struct StrainDetailView: View {
    @Environment(AppModel.self) private var model
    let key: String
    @State private var selected: Date?

    var body: some View {
        if let group = model.strains.first(where: { $0.key == key }) {
            content(group)
        } else {
            ContentUnavailableView("Strain removed", systemImage: "leaf")
        }
    }

    private func content(_ group: StrainGroup) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(group.name)
                        .font(.largeTitle.bold())
                        .fontDesign(.rounded)
                    if !group.producers.isEmpty {
                        Text(group.producers.joined(separator: ", "))
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                .appearLift()

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    figure(String(localized: "Bags"), "\(group.bags.count)", "square.stack.3d.up")
                    figure(String(localized: "Total"), group.totalGrams.gramsLabel, "scalemass")
                    figure(String(localized: "Average THC"), group.averageTHC.map { $0.formatted(.number.precision(.fractionLength(1))) + "%" } ?? "–", "drop")
                    figure(String(localized: "THC range"), group.thcRange.map { range in
                        range.lowerBound == range.upperBound ? "\(range.lowerBound.formatted())%" : "\(range.lowerBound.formatted())–\(range.upperBound.formatted())%"
                    } ?? "–", "arrow.left.and.right")
                    if let rating = group.averageRating {
                        figure(String(localized: "Score"), rating.formatted(.number.precision(.fractionLength(1))) + " / 10", "star")
                    }
                    let stash = group.bags.filter { $0.stock != .empty && $0.form.isWeighed }.map(\.remaining).reduce(0, +)
                    if stash > 0 {
                        figure(String(localized: "In stash"), stash.gramsLabel, "bag")
                    }
                }
                .appearLift(delay: 0.05)

                if LibraryLink.hasContent(for: group.name, in: model.strainCatalog) {
                    LibraryLink(productName: group.name)
                        .glassCard()
                }

                let points = group.bags.filter { $0.thc != nil }
                if points.count > 1 {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("THC across bags").font(.headline)
                        Chart(points) { bag in
                            LineMark(x: .value(String(localized: "Collected"), bag.collectedOn), y: .value("THC", bag.thc!.percent))
                                .foregroundStyle(Theme.leaf)
                                .interpolationMethod(.monotone)
                            PointMark(x: .value(String(localized: "Collected"), bag.collectedOn), y: .value("THC", bag.thc!.percent))
                                .foregroundStyle(Theme.leafMid)
                                .symbolSize(80)
                            if let selected, Calendar.taima.isDate(bag.collectedOn, inSameDayAs: selected) {
                                RuleMark(x: .value(String(localized: "Collected"), bag.collectedOn))
                                    .foregroundStyle(.secondary.opacity(0.4))
                                    .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                                        Text("\(bag.thc!.label) · \(bag.collectedOn.formatted(date: .abbreviated, time: .omitted))")
                                            .font(.caption.weight(.semibold))
                                            .padding(6)
                                            .background(.regularMaterial, in: .capsule)
                                    }
                            }
                        }
                        .chartXSelection(value: $selected)
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(height: 160)
                    }
                    .glassCard()
                    .appearLift(delay: 0.1)
                }

                let insights = ExperienceInsights(bags: group.bags)
                if !(insights.positive.isEmpty && insights.negative.isEmpty && insights.flavors.isEmpty) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How it was").font(.headline)
                        if !insights.positive.isEmpty {
                            TagCloud(tags: insights.positive.map { ($0.name, $0.count) }, hue: Theme.leafMid)
                        }
                        if !insights.negative.isEmpty {
                            TagCloud(tags: insights.negative.map { ($0.name, $0.count) }, hue: .orange)
                        }
                        if !insights.flavors.isEmpty {
                            TagCloud(tags: insights.flavors.map { ($0.name, $0.count) }, hue: .teal)
                        }
                    }
                    .glassCard()
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Bags").font(.headline)
                    ForEach(group.bags) { bag in
                        NavigationLink(value: bag.id) {
                            BagRow(bag: bag)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        if bag.id != group.bags.last?.id { Divider() }
                    }
                }
                .glassCard()
                .appearLift(delay: 0.15)
            }
            .padding()
        }
        .background(GlowBackground())
        .navigationBarTitleDisplayMode(.inline)
    }

    private func figure(_ title: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
                .fontDesign(.rounded)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .glassCard(padding: 14)
        .accessibilityElement(children: .combine)
    }
}
