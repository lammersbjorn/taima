import SwiftUI
import TaimaCore

/// Loads a stored photo off the main thread. Thumbnails are cached, so
/// lists scrolled back to or seen on another tab show them at once.
struct BagPhoto: View {
    @Environment(AppModel.self) private var model
    let name: String?
    var thumbnail = true
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Rectangle().fill(Color.leafSurface)
            // The placeholder stays underneath until the photo covers it.
            Image(systemName: "leaf.fill")
                .font(thumbnail ? .title3 : .largeTitle)
                .foregroundStyle(.tint.opacity(0.5))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            }
        }
        .clipped()
        .task(id: name) {
            guard let name else { image = nil; return }
            let key = (thumbnail ? "t:" : "f:") + name as NSString
            if thumbnail, let cached = PhotoCache.shared.object(forKey: key) {
                image = cached
                return
            }
            let url = thumbnail ? model.photos.thumbnailURL(for: name) : model.photos.url(for: name)
            let loaded = await Task.detached(priority: .userInitiated) {
                UIImage(contentsOfFile: url.path)?.preparingForDisplay()
            }.value
            if thumbnail, let loaded { PhotoCache.shared.setObject(loaded, forKey: key) }
            withAnimation(.easeOut(duration: 0.15)) { image = loaded }
        }
        .accessibilityHidden(true)
    }
}

/// Decoded thumbnails; iOS empties it under memory pressure.
enum PhotoCache {
    static let shared: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 300
        return cache
    }()
}

/// "1 bag", "3 bags".
func counted(_ count: Int, _ singular: String, _ plural: String? = nil) -> String {
    "\(count) " + (count == 1 ? singular : plural ?? singular + "s")
}

/// An hour of the day in the person's clock style: "18:00" or "6 PM".
func hourLabel(_ hour: Int) -> String {
    let date = Calendar.current.date(bySettingHour: hour % 24, minute: 0, second: 0, of: .now) ?? .now
    return date.formatted(.dateTime.hour())
}

extension Color {
    static let leafSurface = Color("Leaf")
}

/// A compact value pill, e.g. "THC 24%".
struct Chip: View {
    let title: String
    let value: String
    var prominent = false

    var body: some View {
        HStack(spacing: 4) {
            if !title.isEmpty {
                Text(title)
                    .foregroundStyle(prominent ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            }
            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .lineLimit(1)
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(prominent ? AnyShapeStyle(.tint.opacity(0.14)) : AnyShapeStyle(.fill.tertiary), in: .capsule)
        .accessibilityElement(children: .combine)
    }
}

/// A value the reader is unsure of: worth a look before saving.
struct CheckMark: View {
    var body: some View {
        Image(systemName: "exclamationmark.circle.fill")
            .font(.caption)
            .foregroundStyle(.orange)
            .accessibilityLabel("Read from label, please check")
    }
}

/// Marks a value that was read from the label and not yet changed.
struct DetectedMark: View {
    var body: some View {
        Image(systemName: "text.viewfinder")
            .font(.caption)
            .foregroundStyle(.tint)
            .accessibilityLabel("Read from label")
    }
}

nonisolated extension Double {
    var gramsLabel: String {
        formatted(.number.precision(.fractionLength(0...1))) + " g"
    }
}

extension Bag {
    /// The grower when known and when the bag was collected, always in
    /// that order, so the line means the same thing on every row.
    var subtitle: String {
        let date = collectedOn.formatted(date: .abbreviated, time: .omitted)
        guard let producer, !producer.isEmpty else { return date }
        return "\(producer) · \(date)"
    }
}

extension String: @retroactive Identifiable {
    public var id: String { self }
}

/// A small badge for a bag's stock state.
struct StockBadge: View {
    let bag: Bag

    var body: some View {
        switch bag.stock {
        case .full:
            Chip(title: "", value: "Full", prominent: true)
        case .open:
            Chip(title: "Open", value: bag.unitsLeft.map { "\($0) left" } ?? bag.remaining.gramsLabel, prominent: true)
        case .empty:
            // Most of a collection is empty bags; only stock gets a pill.
            EmptyView()
        }
    }
}
