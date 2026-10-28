import Charts
import SwiftUI
import TaimaCore

enum StatsRange: String, CaseIterable, Identifiable {
    case quarter, half, year, all
    var id: String { rawValue }
    var label: String {
        switch self {
        case .quarter: String(localized: "3M")
        case .half: String(localized: "6M")
        case .year: String(localized: "1Y")
        case .all: String(localized: "All")
        }
    }
    /// Written out, for headings and VoiceOver.
    var title: String {
        switch self {
        case .quarter: String(localized: "The last 3 months")
        case .half: String(localized: "The last 6 months")
        case .year: String(localized: "The last year")
        case .all: String(localized: "All time")
        }
    }
    var months: Int? {
        switch self {
        case .quarter: 3
        case .half: 6
        case .year: 12
        case .all: nil
        }
    }
}

enum MonthMetric: String, CaseIterable, Identifiable {
    case bags, grams
    var id: String { rawValue }
    var label: String { self == .bags ? String(localized: "Bags") : String(localized: "Grams") }
}

struct StatsView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("stats.range") private var range = StatsRange.all
    @State private var showingYear = false

    private var bags: [Bag] {
        guard let months = range.months,
              let start = Calendar.taima.date(byAdding: .month, value: -months, to: .now) else { return model.bags }
        return model.bags.filter { $0.collectedOn >= start }
    }

    var body: some View {
        NavigationStack {
            Group {
                if model.bags.isEmpty {
                    ContentUnavailableView {
                        VStack(spacing: 8) {
                            Mascot(size: 100)
                            Text("No statistics yet").font(.title2.bold())
                        }
                    } description: {
                        Text("Add a few bags and your totals, THC spread and growers show up here.")
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            Picker("Range", selection: $range.animation(.snappy)) {
                                ForEach(StatsRange.allCases) { Text($0.label).accessibilityLabel($0.title).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            let bags = self.bags
                            if bags.isEmpty {
                                ContentUnavailableView {
                                    Label("No bags in \(range.title.lowercased())", systemImage: "calendar")
                                } description: {
                                    Text("Nothing was collected in this period.")
                                } actions: {
                                    Button("Show all time") { withAnimation(.snappy) { range = .all } }
                                }
                            } else {
                            StatsContent(stats: CollectionStats(bags: bags), bags: bags, inventory: model.inventory, range: range,
                                         experience: ExperienceInsights(bags: bags), sessions: SessionInsights(bags: bags), spending: SpendingSummary(bags: bags))
                                .id(range)
                            }
                            // Milestones count the whole collection, whatever the range.
                            MilestonesCard(milestones: Milestone.evaluate(model.bags))
                        }
                        .padding()
                    }
                    .background(GlowBackground())
                    #if DEBUG
                    .defaultScrollAnchor(ProcessInfo.processInfo.environment["TAIMA_SCROLL"] == "bottom" ? .bottom : .top)
                    #endif
                }
            }
            .navigationTitle("Stats")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Year in review", systemImage: "sparkles.rectangle.stack") { showingYear = true }
                        .disabled(model.bags.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) { SettingsToolbarButton() }
            }
            .sheet(isPresented: $showingYear) { YearReviewSheet() }
            .navigationDestination(for: StrainInfo.self) { StrainInfoView(strain: $0) }
            .navigationDestination(for: UUID.self) { BagDetailView(id: $0) }
        }
    }
}

private struct StatsContent: View {
    let stats: CollectionStats
    let bags: [Bag]
    let inventory: InventorySummary
    let range: StatsRange

    @State private var metric = MonthMetric.bags
    @State private var selectedMonth: Date?
    @State private var selectedBin: Int?
    @State private var selectedAngle: Int?
    @State private var grown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    private var unknownGrowers: Int { bags.filter { ($0.producer ?? "").isEmpty }.count }
    /// Computed once by StatsView per data change: chart drags re-render
    /// this view many times a second and must not recompute them.
    let experience: ExperienceInsights
    let sessions: SessionInsights
    let spending: SpendingSummary
    private var allFindings: [String] { experience.findings + sessions.findings + spending.findings }
    @State private var selectedHour: Int?
    @State private var selectedPoint: UUID?

    var body: some View {
        VStack(spacing: 16) {
            hero.appearLift()
            LazyVGrid(columns: columns, spacing: 12) {
                Tile(title: String(localized: "Strains"), value: "\(stats.strainCount)", systemImage: "leaf", hue: Theme.leafMid)
                Tile(title: String(localized: "Growers"), value: "\(stats.producerCount)", detail: unknownGrowers > 0 ? String(localized: "\(String(localized: "\(unknownGrowers) bags")) unknown") : nil, systemImage: "building.2", hue: Theme.leafDeep)
                if let strongest = stats.highestTHC {
                    NavigationLink(value: strongest.id) {
                        Tile(title: String(localized: "Strongest"), value: strongest.thc?.label ?? "–", detail: strongest.displayName, systemImage: "bolt.fill", hue: Theme.leafMid)
                    }
                    .buttonStyle(.plain)
                }
                if let cure = stats.averageCureDays {
                    Tile(title: String(localized: "Harvest to pack"), value: String(localized: "\(Int(cure.rounded())) days"), detail: String(localized: "average"), systemImage: "hourglass", hue: .teal)
                }
                if let age = stats.averageAgeAtCollectionDays {
                    Tile(title: String(localized: "Pack to collect"), value: String(localized: "\(Int(age.rounded())) days"), detail: String(localized: "average"), systemImage: "calendar", hue: Theme.leafDeep)
                }
                if let perGram = stats.averagePricePerGram {
                    Tile(title: String(localized: "Per gram"), value: perGram.formatted(.currency(code: "EUR")), detail: String(localized: "from \(bags.filter { $0.pricePerGram != nil }.count) of \(String(localized: "\(bags.count) bags"))"), systemImage: "eurosign", hue: Theme.leafMid)
                }
                if let rating = stats.averageRating {
                    Tile(title: String(localized: "Score"), value: rating.formatted(.number.precision(.fractionLength(1))) + " / 10", detail: String(localized: "average of \(experience.ratedCount)"), systemImage: "star.fill", hue: Theme.leafMid)
                }
                if inventory.usedLast30Days > 0 {
                    Tile(title: String(localized: "Used, 30 days"), value: inventory.usedLast30Days.gramsLabel, detail: String(localized: "\(inventory.dailyAverage.formatted(.number.precision(.fractionLength(2)))) g a day"), systemImage: "flame", hue: .teal)
                }
            }
            .appearLift(delay: 0.05)

            if !allFindings.isEmpty { insightsCard.appearLift(delay: 0.08) }
            if !stats.months.isEmpty { monthsCard.appearLift(delay: 0.1) }
            if !stats.thcBins.isEmpty { thcCard.appearLift(delay: 0.15) }
            if !stats.producers.isEmpty { producerCard.appearLift(delay: 0.2) }
            if sessions.sessionCount >= 3 { rhythmCard }
            if !sessions.methods.isEmpty { methodsCard }
            if spending.pricedBags >= 1 || !spending.shops.isEmpty { spendingCard }
            if experience.thcVersusScore.count >= 2 { scoreCard }
            if !(experience.positive.isEmpty && experience.negative.isEmpty) { effectsCard }
            if !experience.flavors.isEmpty { flavorsCard }
            if experience.byGrower.count >= 1 { growerScoreCard }
            if Set(bags.map(\.form)).count > 1 { formsCard }
            if !stats.sizes.isEmpty { sizesCard }
            if !stats.cureTimes.isEmpty { cureCard }
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.9, bounce: 0.2).delay(0.15)) { grown = true }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(range.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                    Text(String(localized: "\(stats.bagCount) bags"))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(value: Double(stats.bagCount)))
                }
                Spacer()
                Mascot(size: 64)
            }
            HStack(spacing: 0) {
                heroFigure(stats.totalGrams.gramsLabel, String(localized: "collected"))
                heroFigure(stats.averageTHC.map { $0.formatted(.number.precision(.fractionLength(1))) + "%" } ?? "–", String(localized: "avg THC"))
                heroFigure(inventory.stashGrams.gramsLabel, String(localized: "in stash"))
            }
        }
        .padding(20)
        .background(
            Theme.hero,
            in: .rect(cornerRadius: Theme.heroRadius)
        )
        .shadow(color: Theme.leafDeep.opacity(0.18), radius: 12, y: 6)
        .accessibilityElement(children: .combine)
    }

    private func heroFigure(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label).font(.caption).foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Months

    private var monthDomain: ClosedRange<Date> {
        let calendar = Calendar.taima
        let end = calendar.date(byAdding: .month, value: 1, to: calendar.dateInterval(of: .month, for: .now)!.start)!
        let earliest = calendar.date(byAdding: .month, value: -(range.months ?? 6), to: end)!
        return min(stats.months.first?.start ?? earliest, earliest)...end
    }

    private var monthsCard: some View {
        let selected = selectedMonth.flatMap { date in
            stats.months.first { Calendar.taima.isDate($0.start, equalTo: date, toGranularity: .month) }
        }
        return ChartCard(title: String(localized: "Collected per month"), subtitle: selected.map {
            "\($0.start.formatted(.dateTime.month(.wide).year())): \(String(localized: "\($0.count) bags")), \($0.grams.gramsLabel)"
        } ?? String(localized: "Drag across the bars")) {
            Picker("Metric", selection: $metric.animation(.snappy)) {
                ForEach(MonthMetric.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 150)
        } chart: {
            Chart(stats.months) { month in
                let value = metric == .bags ? Double(month.count) : month.grams
                BarMark(x: .value(String(localized: "Month"), month.start, unit: .month), y: .value(metric.label, grown ? value : 0), width: .ratio(0.6))
                    .foregroundStyle(Theme.bar(Theme.leafMid))
                    .opacity(selected == nil || selected == month ? 1 : 0.35)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 6, topTrailingRadius: 6))
                if selected == month {
                    RuleMark(x: .value(String(localized: "Month"), month.start, unit: .month))
                        .foregroundStyle(.clear)
                        .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                            Text(metric == .bags ? "\(month.count)" : month.grams.gramsLabel)
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.regularMaterial, in: .capsule)
                        }
                }
            }
            .chartXScale(domain: monthDomain)
            .chartXSelection(value: $selectedMonth)
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) {
                    AxisValueLabel(format: .dateTime.month(.narrow), centered: true)
                }
            }
            .chartYAxis { AxisMarks(values: .automatic(desiredCount: 3)) { AxisGridLine(); AxisValueLabel() } }
            .frame(height: 190)
            .sensoryFeedback(.selection, trigger: selected?.start)
        }
    }

    // MARK: - THC

    private var thcCard: some View {
        let selectedBags = selectedBin.map { bin in bags.filter { Int($0.thc?.percent.rounded(.down) ?? -1) == bin } } ?? []
        return ChartCard(title: String(localized: "THC spread"), subtitle: selectedBin.map { String(localized: "\(String(localized: "\(selectedBags.count) bags")) at \($0)%") } ?? String(localized: "Tap a bar to see its bags")) {
            EmptyView()
        } chart: {
            VStack(alignment: .leading, spacing: 12) {
                Chart(stats.thcBins) { bin in
                    BarMark(x: .value("THC", "\(bin.lowerBound)%"), y: .value(String(localized: "Bags"), grown ? bin.count : 0))
                        .foregroundStyle(Theme.fill(Theme.leafMid))
                        .opacity(selectedBin == nil || selectedBin == bin.lowerBound ? 1 : 0.35)
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 6, topTrailingRadius: 6))
                        .annotation(position: .top) {
                            if bin.count > 0 {
                                Text("\(bin.count)").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                            }
                        }
                }
                .chartYAxis(.hidden)
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle().fill(.clear).contentShape(.rect)
                            .onTapGesture { location in
                                guard let plot = proxy.plotFrame else { return }
                                let x = location.x - geometry[plot].origin.x
                                if let label: String = proxy.value(atX: x), let bin = Int(label.dropLast()) {
                                    withAnimation(.snappy) { selectedBin = selectedBin == bin ? nil : bin }
                                }
                            }
                    }
                }
                .frame(height: 170)
                .accessibilityRepresentation {
                    // VoiceOver: one button per bar, doing what a tap does.
                    VStack {
                        ForEach(stats.thcBins.filter { $0.count > 0 }) { bin in
                            Button("\(bin.lowerBound)% THC: \(bin.count) bags") {
                                selectedBin = selectedBin == bin.lowerBound ? nil : bin.lowerBound
                            }
                            .accessibilityAddTraits(selectedBin == bin.lowerBound ? .isSelected : [])
                        }
                    }
                }
                .sensoryFeedback(.selection, trigger: selectedBin)
                if !selectedBags.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(selectedBags.prefix(6)) { bag in
                            NavigationLink(value: bag.id) {
                                HStack {
                                    Text(bag.displayName).font(.subheadline).lineLimit(1)
                                    Spacer()
                                    Text(bag.thc?.label ?? "").font(.subheadline.weight(.semibold)).monospacedDigit()
                                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    // MARK: - Growers

    private var producerCard: some View {
        // Named growers first, "Unknown" last and gray.
        let named = stats.producers.filter { $0.label != String(localized: "Unknown") }.prefix(5)
        let producers = Array(named) + stats.producers.filter { $0.label == String(localized: "Unknown") }
        let hues: [Color] = [Theme.leafMid, .teal, Theme.leafDeep, .mint, Theme.leafLight]
        let palette: [Color] = producers.enumerated().map { index, item in
            item.label == String(localized: "Unknown") ? Color.gray.opacity(0.45) : hues[index % hues.count]
        }
        let selectedProducer: CollectionStats.Count? = selectedAngle.flatMap { value in
            var running = 0
            return producers.first { item in
                running += item.count
                return value < running
            }
        }
        return ChartCard(title: String(localized: "Growers"), subtitle: selectedProducer.map { "\($0.label): \(String(localized: "\($0.count) bags")), \($0.grams.gramsLabel)" } ?? String(localized: "Tap a slice")) {
            EmptyView()
        } chart: {
            HStack(spacing: 16) {
                Chart(producers) { item in
                    SectorMark(angle: .value(String(localized: "Bags"), grown ? item.count : 0), innerRadius: .ratio(0.62), angularInset: 2)
                        .cornerRadius(5)
                        .foregroundStyle(by: .value(String(localized: "Grower"), item.label))
                        .opacity(selectedProducer == nil || selectedProducer == item ? 1 : 0.35)
                }
                .chartForegroundStyleScale(domain: producers.map(\.label), range: palette)
                .chartLegend(.hidden)
                .chartAngleSelection(value: $selectedAngle)
                .chartBackground { _ in
                    VStack(spacing: 0) {
                        Text("\(selectedProducer?.count ?? stats.bagCount)")
                            .font(.title2.weight(.bold))
                            .fontDesign(.rounded)
                            .contentTransition(.numericText())
                        Text("bags").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 150, height: 150)
                .sensoryFeedback(.selection, trigger: selectedProducer?.label)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(producers.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 8) {
                            Circle().fill(palette[index]).frame(width: 9, height: 9)
                            Text(item.label).font(.caption).lineLimit(1)
                            Spacer(minLength: 0)
                            Text("\(item.count)").font(.caption.weight(.semibold)).monospacedDigit()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Experience

    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                TintedIconTile(systemImage: "sparkles", hue: Theme.leafMid, size: 30)
                Text("Insights").font(.headline)
            }
            ForEach(allFindings, id: \.self) { line in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Circle().fill(Theme.leafMid).frame(width: 6, height: 6)
                    Text(line).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                }
            }
            Text("From your own scores and notes.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .glassCard(tint: Theme.leafMid)
    }

    private var scoreCard: some View {
        let points = experience.thcVersusScore
        let selected = points.first { $0.id == selectedPoint }
        return ChartCard(title: String(localized: "THC and your score"), subtitle: selected.map { "\($0.name): \($0.thc.formatted())% THC, \($0.score.formatted()) / 10" } ?? String(localized: "Tap a dot")) {
            EmptyView()
        } chart: {
            Chart(points) { point in
                PointMark(x: .value("THC", point.thc), y: .value(String(localized: "Score"), point.score))
                    .symbolSize(selected?.id == point.id ? 220 : 110)
                    .foregroundStyle(selected == nil || selected?.id == point.id ? Theme.leafMid : Theme.leafMid.opacity(0.35))
            }
            .chartXScale(domain: .automatic(includesZero: false))
            .chartYScale(domain: 0...10)
            .chartXAxisLabel("THC %")
            .chartYAxisLabel("Score")
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle().fill(.clear).contentShape(.rect)
                        .onTapGesture { location in
                            guard let plot = proxy.plotFrame else { return }
                            let origin = geometry[plot].origin
                            let nearest = points.min { a, b in
                                distance(proxy, a, location, origin) < distance(proxy, b, location, origin)
                            }
                            withAnimation(.snappy) { selectedPoint = nearest?.id == selectedPoint ? nil : nearest?.id }
                        }
                }
            }
            .frame(height: 200)
            .accessibilityRepresentation {
                VStack {
                    ForEach(points) { point in
                        Button("\(point.name): \(point.thc.formatted())% THC, scored \(point.score.formatted()) of 10") {
                            selectedPoint = selectedPoint == point.id ? nil : point.id
                        }
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: selectedPoint)
        }
    }

    private func distance(_ proxy: ChartProxy, _ point: ExperienceInsights.Point, _ location: CGPoint, _ origin: CGPoint) -> CGFloat {
        guard let x = proxy.position(forX: point.thc), let y = proxy.position(forY: point.score) else { return .infinity }
        return hypot(x + origin.x - location.x, y + origin.y - location.y)
    }

    private var spendingCard: some View {
        let summary = spending
        return ChartCard(title: String(localized: "Spending"), subtitle: String(localized: "\(summary.total.formatted(.currency(code: "EUR"))) over \(String(localized: "\(summary.pricedBags) priced bags"))")) {
            EmptyView()
        } chart: {
            VStack(alignment: .leading, spacing: 14) {
                if summary.months.count >= 1 {
                    Chart(summary.months) { month in
                        BarMark(x: .value(String(localized: "Month"), month.start, unit: .month), y: .value(String(localized: "Euros"), grown ? month.euros : 0), width: .ratio(0.6))
                            .foregroundStyle(Theme.fill(Theme.leafDeep))
                            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 5, topTrailingRadius: 5))
                    }
                    .chartXAxis { AxisMarks(values: .stride(by: .month)) { AxisValueLabel(format: .dateTime.month(.narrow), centered: true) } }
                    .chartYAxis { AxisMarks(values: .automatic(desiredCount: 3)) { value in AxisGridLine(); AxisValueLabel { Text((value.as(Double.self) ?? 0).formatted(.currency(code: "EUR").precision(.fractionLength(0)))) } } }
                    .frame(height: 130)
                }
                if !summary.shops.isEmpty {
                    Text("Shops").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    BarList(rows: summary.shops.prefix(6).map { shop in
                        .init(id: shop.id, label: shop.city.map { "\(shop.name), \($0)" } ?? shop.name, value: Double(shop.visits),
                              detail: "\(shop.visits)×" + (shop.pricePerGram.map { " · \($0.formatted(.currency(code: "EUR")))/g" } ?? ""))
                    }, hue: Theme.leafDeep, grown: grown)
                }
            }
        }
    }

    private var rhythmCard: some View {
        let hours = sessions.byHour
        let selected = selectedHour.map { hour in (hour, hours[hour]) }
        return ChartCard(title: String(localized: "When you use"), subtitle: selected.map { "\(hourLabel($0.0))–\(hourLabel($0.0 + 1)): \(String(localized: "\($0.1) sessions"))" } ?? String(localized: "\(String(localized: "\(sessions.sessionCount) sessions")) by hour of day")) {
            EmptyView()
        } chart: {
            VStack(alignment: .leading, spacing: 14) {
                Chart(Array(hours.enumerated()), id: \.offset) { hour, count in
                    BarMark(x: .value(String(localized: "Hour"), hour), y: .value(String(localized: "Sessions"), grown ? count : 0), width: .ratio(0.7))
                        .foregroundStyle(Theme.fill(Theme.leafMid))
                        .opacity(selectedHour == nil || selectedHour == hour ? 1 : 0.35)
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 3, topTrailingRadius: 3))
                }
                .chartXScale(domain: -0.5...23.5)
                .chartXAxis { AxisMarks(values: [0, 6, 12, 18, 23]) { value in AxisValueLabel { Text(hourLabel(value.as(Int.self) ?? 0)) } } }
                .chartYAxis(.hidden)
                .chartXSelection(value: Binding(get: { selectedHour }, set: { selectedHour = $0.map { min(23, max(0, $0)) } }))
                .frame(height: 120)
                .sensoryFeedback(.selection, trigger: selectedHour)
                HStack(spacing: 6) {
                    // Monday first, in the person's language.
                    let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
                    let days = (0..<7).map { symbols[($0 + 1) % 7] }
                    let peak = max(sessions.byWeekday.max() ?? 1, 1)
                    ForEach(0..<7, id: \.self) { index in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Theme.leafMid.opacity(0.15 + 0.85 * Double(sessions.byWeekday[index]) / Double(peak)))
                                .frame(height: 26)
                            Text(days[index]).font(.caption2).foregroundStyle(.secondary)
                        }
                        .accessibilityElement()
                        .accessibilityLabel("\(Calendar.current.standaloneWeekdaySymbols[(index + 1) % 7]): \(String(localized: "\(sessions.byWeekday[index]) sessions"))")
                    }
                }
            }
        }
    }

    private var methodsCard: some View {
        ChartCard(title: String(localized: "How you use"), subtitle: String(localized: "Sessions and grams per method")) { EmptyView() } chart: {
            VStack(alignment: .leading, spacing: 14) {
                BarList(rows: sessions.methods.map { .init(id: $0.label, label: $0.label, value: Double($0.count), detail: "\($0.count)× · \($0.grams.gramsLabel)") }, hue: Theme.leafMid, grown: grown)
                if let share = sessions.tobaccoShare {
                    HStack {
                        Label("Mixed with tobacco", systemImage: "nosign").font(.subheadline)
                        Spacer()
                        Text("\(Int((share * 100).rounded()))%").font(.subheadline.weight(.semibold)).monospacedDigit()
                    }
                }
                if !sessions.liftByTimeOfDay.isEmpty {
                    Text("Mood change by time of day").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(sessions.liftByTimeOfDay) { lift in
                        HStack {
                            Text("\(lift.label) · \(lift.count)×").font(.subheadline)
                            Spacer()
                            Text((lift.change >= 0 ? "+" : "") + lift.change.formatted(.number.precision(.fractionLength(0...1))))
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                        }
                    }
                }
                if sessions.liftByTHC.count > 1 {
                    Text("Mood change by THC").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(sessions.liftByTHC) { lift in
                        HStack {
                            Text("\(lift.label) · \(lift.count)×").font(.subheadline)
                            Spacer()
                            Text((lift.change >= 0 ? "+" : "") + lift.change.formatted(.number.precision(.fractionLength(0...1))))
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                        }
                    }
                    Text("Patterns in your own log, not causes.").font(.caption).foregroundStyle(.tertiary)
                }
                if !sessions.liftByMethod.isEmpty {
                    Text("Mood change").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(sessions.liftByMethod) { lift in
                        HStack {
                            Text(lift.label).font(.subheadline)
                            Spacer()
                            Text((lift.change >= 0 ? "+" : "") + lift.change.formatted(.number.precision(.fractionLength(0...1))))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(lift.change > 0 ? Theme.leafDeep : .secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
    }

    private var effectsCard: some View {
        ChartCard(title: String(localized: "Effects"), subtitle: String(localized: "How often you noted each")) { EmptyView() } chart: {
            VStack(alignment: .leading, spacing: 16) {
                if !experience.positive.isEmpty {
                    BarList(rows: experience.positive.prefix(6).map { .init(id: $0.name, label: ExperienceTags.label(for: $0.name), value: Double($0.count), detail: "\($0.count)") }, hue: Theme.leafMid, grown: grown)
                }
                if !experience.negative.isEmpty {
                    Text("Downsides").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    BarList(rows: experience.negative.prefix(5).map { .init(id: $0.name, label: ExperienceTags.label(for: $0.name), value: Double($0.count), detail: "\($0.count)") }, hue: .orange, grown: grown)
                }
            }
        }
    }

    private var flavorsCard: some View {
        ChartCard(title: String(localized: "Taste and smell"), subtitle: nil) { EmptyView() } chart: {
            TagCloud(tags: experience.flavors.prefix(14).map { ($0.name, $0.count) }, hue: .teal)
        }
    }

    private var growerScoreCard: some View {
        ChartCard(title: String(localized: "Score by grower"), subtitle: String(localized: "Average of your scores")) { EmptyView() } chart: {
            BarList(rows: experience.byGrower.prefix(6).map { .init(id: $0.label, label: $0.label, value: $0.score, detail: "\($0.score.formatted(.number.precision(.fractionLength(1)))) · \($0.count)×") }, hue: Theme.leafDeep, grown: grown)
        }
    }

    // MARK: - Sizes and cure

    private var formsCard: some View {
        let counts = ProductForm.allCases.map { form in (form, bags.filter { $0.form == form }) }.filter { !$0.1.isEmpty }
        return ChartCard(title: String(localized: "Bags, prerolls and jars"), subtitle: nil) { EmptyView() } chart: {
            HStack(spacing: 12) {
                ForEach(counts, id: \.0) { form, items in
                    VStack(spacing: 6) {
                        TintedIconTile(systemImage: form.symbol, hue: Theme.leafMid, size: 36)
                        Text("\(items.count)").font(.title3.weight(.bold)).fontDesign(.rounded)
                        Text(form.label).font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private var sizesCard: some View {
        ChartCard(title: String(localized: "Bag sizes"), subtitle: nil) { EmptyView() } chart: {
            // Sorted by size and scaled by grams, so five 1 g bags don't
            // look as large as five 5 g bags.
            let sizes = stats.sizes.sorted { ($0.grams / Double(max($0.count, 1))) < ($1.grams / Double(max($1.count, 1))) }
            BarList(rows: sizes.map { .init(id: $0.label, label: $0.label, value: $0.grams, detail: "\($0.count)× · \($0.grams.gramsLabel)") },
                    hue: Theme.leafMid, grown: grown)
        }
    }

    private var cureCard: some View {
        let items = Array(stats.cureTimes.sorted { $0.days > $1.days }.prefix(8))
        return ChartCard(title: String(localized: "Harvest to pack"), subtitle: String(localized: "Days between harvest and packing")) { EmptyView() } chart: {
            BarList(rows: items.map { .init(id: $0.bag.id.uuidString, label: $0.bag.displayName, value: Double($0.days), detail: String(localized: "\($0.days) days")) },
                    hue: .teal, grown: grown)
        }
    }
}

/// Labelled horizontal bars: the name above its bar, the value at the end.
/// Plain layout instead of Swift Charts, so long names never collide with
/// bars or push values off a narrow screen.
struct BarList: View {
    struct Row: Identifiable {
        let id: String
        let label: String
        let value: Double
        let detail: String
    }

    let rows: [Row]
    var hue: Color = Theme.leafMid
    var grown = true

    var body: some View {
        let peak = max(rows.map(\.value).max() ?? 1, 0.0001)
        VStack(alignment: .leading, spacing: 12) {
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.label)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(row.detail)
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(hue.opacity(0.12))
                            Capsule()
                                .fill(Theme.fill(hue))
                                .frame(width: max(8, proxy.size.width * (grown ? row.value / peak : 0)))
                        }
                    }
                    .frame(height: 8)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(row.label), \(row.detail)")
            }
        }
    }
}

private struct Tile: View {
    let title: String
    let value: String
    var detail: String?
    let systemImage: String
    var hue: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TintedIconTile(systemImage: systemImage, hue: hue, size: 30)
            Text(value)
                .font(.title3.weight(.bold))
                .fontDesign(.rounded)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.caption.weight(.medium))
                Text(detail ?? " ").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .glassCard(padding: 14)
        .accessibilityElement(children: .combine)
    }
}

private struct ChartCard<Accessory: View, Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let accessory: Accessory
    @ViewBuilder let chart: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .contentTransition(.opacity)
                            .animation(.snappy, value: subtitle)
                    }
                }
                Spacer()
                accessory
            }
            chart
        }
        .glassCard()
    }
}
