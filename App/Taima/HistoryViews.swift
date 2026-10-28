import SwiftUI
import TaimaCore

/// A month of use: each day shaded by grams, days without use marked, and
/// a tap for that day's details. Like Daylio's calendar, for sessions.
struct UsageCalendarCard: View {
    @Environment(AppModel.self) private var model
    @State private var month = Calendar.taima.dateInterval(of: .month, for: .now)?.start ?? .now
    @State private var selected: Date?

    /// Weeks start on the person's own first weekday.
    private var calendar: Calendar {
        var calendar = Calendar.taima
        calendar.firstWeekday = Calendar.current.firstWeekday
        calendar.locale = .current
        return calendar
    }

    var body: some View {
        let calendar = self.calendar
        let months = UsageMonth.range(bags: model.bags, calendar: calendar)
        let data = UsageMonth(bags: model.bags, month: month, calendar: calendar)
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let weekdays = (0..<7).map { symbols[(calendar.firstWeekday - 1 + $0) % 7] }
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Calendar").font(.headline)
                    Text(month.formatted(.dateTime.month(.wide).year()))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                Spacer()
                Button("Previous month", systemImage: "chevron.left") { step(-1, within: months) }
                    .disabled(month <= (months.first ?? month))
                    .frame(minWidth: 44, minHeight: 44)
                Button("Next month", systemImage: "chevron.right") { step(1, within: months) }
                    .disabled(month >= (months.last ?? month))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                ForEach(0..<data.leadingBlanks, id: \.self) { _ in Color.clear.frame(height: 40) }
                ForEach(data.days) { day in
                    dayCell(day, peak: max(data.peakGrams, 0.01), calendar: calendar)
                }
            }

            Group {
                if let selected, let day = data.days.first(where: { $0.date == selected }) {
                    Text(describe(day))
                } else {
                    Text("\(String(localized: "\(data.daysWithUse) days")) with use, \(String(localized: "\(data.daysWithoutUse) days")) without")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .contentTransition(.opacity)
        }
        .glassCard()
        .sensoryFeedback(.selection, trigger: selected)
    }

    private func dayCell(_ day: UsageMonth.Day, peak: Double, calendar: Calendar) -> some View {
        let isSelected = selected == day.date
        let isToday = calendar.isDateInToday(day.date)
        return Button {
            withAnimation(.snappy) { selected = isSelected ? nil : day.date }
        } label: {
            Text("\(calendar.component(.day, from: day.date))")
                .font(.footnote.weight(isToday ? .bold : .regular))
                .monospacedDigit()
                .foregroundStyle(day.sessions > 0 && day.grams / peak > 0.55 ? AnyShapeStyle(.white) : day.isTracked ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                .frame(maxWidth: .infinity, minHeight: 40)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(fill(for: day, peak: peak))
                }
                .overlay {
                    if isSelected || isToday {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isSelected ? Theme.leafMid : .secondary.opacity(0.5), lineWidth: isSelected ? 2 : 1)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(describe(day))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func fill(for day: UsageMonth.Day, peak: Double) -> AnyShapeStyle {
        if day.sessions > 0 {
            AnyShapeStyle(Theme.leafMid.opacity(0.3 + 0.7 * min(1, day.grams / peak)))
        } else if day.isTracked {
            AnyShapeStyle(.fill.tertiary)
        } else {
            AnyShapeStyle(.clear)
        }
    }

    private func describe(_ day: UsageMonth.Day) -> String {
        let date = day.date.formatted(.dateTime.weekday(.wide).day().month(.wide))
        if day.sessions > 0 {
            return String(localized: "\(date): \(day.grams.gramsLabel) in \(String(localized: "\(day.sessions) sessions"))")
        }
        return day.isTracked ? String(localized: "\(date): no use") : String(localized: "\(date): nothing logged yet")
    }

    private func step(_ delta: Int, within months: [Date]) {
        guard let next = calendar.date(byAdding: .month, value: delta, to: month),
              let first = months.first, let last = months.last, next >= first, next <= last else { return }
        withAnimation(.snappy) {
            month = next
            selected = nil
        }
    }
}

/// Bags collected around this date in earlier years.
struct OnThisDayCard: View {
    let memories: [OnThisDay.Memory]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("On this day", systemImage: "clock.arrow.circlepath").font(.headline)
            ForEach(memories.prefix(3)) { memory in
                NavigationLink(value: memory.bag.id) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(memory.yearsAgo == 1 ? String(localized: "A year ago") : String(localized: "\(memory.yearsAgo) years ago"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.secondaryText)
                        BagRow(bag: memory.bag)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .glassCard()
    }
}
