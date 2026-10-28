import SwiftUI
import TaimaCore

/// A review card to send to friends. Made on the phone; the product code,
/// price and notes are left out.
struct ShareCardView: View {
    let bag: Bag
    let photo: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let photo {
                        Image(uiImage: photo).resizable().scaledToFill()
                    } else {
                        Theme.hero
                    }
                }
                .frame(width: 360, height: 260)
                .clipped()
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 2) {
                    Text(bag.displayName)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    if let producer = bag.producer {
                        Text(producer).font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.85))
                    }
                }
                .padding(18)
            }
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    if let thc = bag.thc { pill("THC", thc.label) }
                    if let cbd = bag.cbd { pill("CBD", cbd.label) }
                    if let grams = bag.grams { pill(bag.form.label, grams.gramsLabel) }
                    if let type = bag.strainType { pill("", type.label) }
                }
                if let score = bag.rating10 {
                    HStack(spacing: 10) {
                        HalfStars(score: score, size: .title3)
                        Text(score.formatted(.number.precision(.fractionLength(0...1))) + " / 10")
                            .font(.headline)
                    }
                }
                if !bag.positiveEffects.isEmpty {
                    TagCloud(tags: bag.positiveEffects.prefix(5).map { ($0, nil) }, hue: Theme.leafMid)
                }
                if !bag.flavorTags.isEmpty {
                    TagCloud(tags: bag.flavorTags.prefix(5).map { ($0, nil) }, hue: .teal)
                }
                HStack {
                    Image("Mascot").resizable().scaledToFit().frame(width: 26, height: 26)
                    Text("Taima").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                    Spacer()
                    if let packed = bag.packedOn {
                        Text("Packed " + packed.formatted(date: .abbreviated, time: .omitted))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(18)
        }
        .frame(width: 360)
        .background(Color(.systemBackground))
        .clipShape(.rect(cornerRadius: 28))
    }

    private func pill(_ title: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            if !title.isEmpty { Text(title).foregroundStyle(Theme.leafDeep) }
            Text(value).fontWeight(.semibold)
        }
        .font(.subheadline)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Theme.leafMid.opacity(0.14), in: .capsule)
    }
}

/// Previews the card and hands the rendered image to the share sheet.
struct ShareCardSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    let bag: Bag
    @State private var rendered: UIImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let rendered {
                        Image(uiImage: rendered)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 360)
                            .shadow(color: .black.opacity(0.15), radius: 16, y: 8)
                            .transition(.scale(scale: 0.95).combined(with: .opacity))
                        ShareLink(item: Image(uiImage: rendered), preview: SharePreview(bag.displayName, image: Image(uiImage: rendered))) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: 260)
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                        Text("The card leaves out the product code, price and your notes.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView().padding(60)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .background(GlowBackground())
            .navigationTitle("Share card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done", systemImage: "checkmark") { dismiss() } }
            }
            .task { await render() }
        }
    }

    private func render() async {
        let url = bag.mainPhoto.map { model.photos.url(for: $0) }
        let photo = await Task.detached { url.flatMap { UIImage(contentsOfFile: $0.path) } }.value
        let renderer = ImageRenderer(content: ShareCardView(bag: bag, photo: photo).environment(\.colorScheme, scheme))
        renderer.scale = 3
        withAnimation(.spring(duration: 0.4)) { rendered = renderer.uiImage }
    }
}

/// A year in one card. Like the bag card, no codes, prices or notes.
struct YearReviewCard: View {
    let review: YearReview

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("My \(String(review.year))")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("in Taima").font(.headline).foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                Image("Mascot").resizable().scaledToFit().frame(width: 70, height: 70)
            }
            HStack(spacing: 10) {
                figure("\(review.bagCount)", review.bagCount == 1 ? "item" : "items")
                figure(review.grams.gramsLabel, "collected")
                figure("\(review.strainCount)", "strains")
                figure("\(review.growerCount)", "growers")
            }
            VStack(alignment: .leading, spacing: 10) {
                if let favourite = review.favourite, let score = favourite.rating10 {
                    line("star.fill", "Favourite", "\(favourite.displayName), \(score.formatted(.number.precision(.fractionLength(0...1)))) / 10")
                }
                if let grower = review.topGrower { line("building.2.fill", "Most from", grower) }
                if let effect = review.topEffect { line("sparkles", "Most often", effect.lowercased()) }
                if let month = review.busiestMonth { line("calendar", "Busiest month", month.formatted(.dateTime.month(.wide))) }
            }
        }
        .foregroundStyle(.white)
        .padding(24)
        .frame(width: 360)
        .background(Theme.hero)
        .clipShape(.rect(cornerRadius: 28))
    }

    private func figure(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.caption2).foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.white.opacity(0.14), in: .rect(cornerRadius: 14))
    }

    private func line(_ symbol: String, _ title: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).frame(width: 22)
            Text(title).foregroundStyle(.white.opacity(0.8))
            Spacer()
            Text(value).fontWeight(.semibold).lineLimit(1)
        }
        .font(.subheadline)
    }
}

struct YearReviewSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var year = Calendar.taima.component(.year, from: .now)
    @State private var rendered: UIImage?

    private var years: [Int] {
        Array(Set(model.bags.map { Calendar.taima.component(.year, from: $0.collectedOn) })).sorted(by: >)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if years.count > 1 {
                        Picker("Year", selection: $year) {
                            ForEach(years, id: \.self) { Text(String($0)).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    if let rendered {
                        Image(uiImage: rendered)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 360)
                            .shadow(color: .black.opacity(0.15), radius: 16, y: 8)
                        ShareLink(item: Image(uiImage: rendered), preview: SharePreview("My \(String(year)) in Taima", image: Image(uiImage: rendered))) {
                            Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: 260)
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .background(GlowBackground())
            .navigationTitle("Year in review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done", systemImage: "checkmark") { dismiss() } }
            }
            .task(id: year) {
                let renderer = ImageRenderer(content: YearReviewCard(review: YearReview(bags: model.bags, year: year)))
                renderer.scale = 3
                withAnimation(.snappy) { rendered = renderer.uiImage }
            }
        }
    }
}
