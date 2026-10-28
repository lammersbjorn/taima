import SwiftUI
import TaimaCore

/// Search the bundled strain library.
struct StrainLibraryList: View {
    @Environment(AppModel.self) private var model
    let query: String

    var body: some View {
        let results = model.strainCatalog.search(query)
        List {
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                if !model.wishlist.isEmpty {
                    Section("Want to try") {
                        ForEach(model.wishlist) { item in
                            if let strain = model.strainCatalog.info(named: item.name) {
                                let tried = !model.bags(of: strain).isEmpty
                                NavigationLink(value: strain) {
                                    HStack {
                                        StrainLibraryRow(strain: strain)
                                        Spacer()
                                        if tried {
                                            Label("Tried", systemImage: "checkmark.circle.fill")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(Theme.leafMid)
                                        }
                                    }
                                }
                                .swipeActions {
                                    Button("Remove", systemImage: "heart.slash", role: .destructive) { model.toggleWish(strain) }
                                }
                            }
                        }
                    }
                }
                Section {
                    ForEach(featured) { strain in
                        NavigationLink(value: strain) { StrainLibraryRow(strain: strain) }
                    }
                } header: {
                    Text("Well-known strains")
                } footer: {
                    Text("\(model.strainCatalog.strains.count.formatted()) strains. Search by name or alias, such as GSC or Sneeuwwitje.")
                }
            } else {
                ForEach(results) { strain in
                    NavigationLink(value: strain) { StrainLibraryRow(strain: strain) }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .overlay {
            if !query.isEmpty && results.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
    }

    private var featured: [StrainInfo] {
        ["Girl Scout Cookies", "Amnesia Haze", "White Widow", "Super Silver Haze", "Gelato", "Zkittlez", "Northern Lights", "Jack Herer"]
            .compactMap(model.strainCatalog.info(named:))
    }
}

struct StrainLibraryRow: View {
    let strain: StrainInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(strain.name).font(.headline)
                if strain.isCross {
                    Image(systemName: "arrow.triangle.merge").font(.caption).foregroundStyle(.secondary)
                        .accessibilityLabel("Cross")
                }
            }
            HStack(spacing: 6) {
                if let type = strain.trustedType { Chip(title: "", value: type.label, prominent: true) }
                if let lean = strain.lean { Text(ExperienceTags.label(for: lean)).font(.caption).foregroundStyle(.secondary) }
                if !strain.aliases.isEmpty {
                    Text("aka \(strain.aliases.prefix(2).joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

/// Everything the library knows about one strain, with your own bags of it.
struct StrainInfoView: View {
    @Environment(AppModel.self) private var model
    let strain: StrainInfo

    var body: some View {
        let catalog = model.strainCatalog
        let children = catalog.children(of: strain)
        let yours = model.bags(of: strain)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(strain.name)
                        .font(.largeTitle.bold())
                        .fontDesign(.rounded)
                    if !strain.aliases.isEmpty {
                        Text("Also known as \(strain.aliases.joined(separator: ", "))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 8) {
                        if let type = strain.trustedType {
                            Chip(title: "", value: type.label, prominent: true)
                        } else if strain.type == .hybrid {
                            Chip(title: "", value: String(localized: "Type unknown"))
                        }
                        if let lean = strain.lean { Chip(title: "", value: ExperienceTags.label(for: lean)) }
                        if let breeder = strain.breeder, !breeder.isEmpty { Chip(title: String(localized: "by"), value: breeder) }
                    }
                }
                .appearLift()

                if !strain.parents.isEmpty || !children.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            // Without known parents the card is only about what it was used in.
                            Label(strain.parents.isEmpty ? String(localized: "Used in") : strain.isCross ? String(localized: "A cross of") : String(localized: "Descends from"),
                                  systemImage: strain.parents.isEmpty ? "arrow.triangle.branch" : "arrow.triangle.merge")
                                .font(.headline)
                            Spacer()
                            NavigationLink("Family tree") { FamilyTreeView(strain: strain) }
                                .font(.subheadline.weight(.semibold))
                        }
                        if !strain.parents.isEmpty {
                            FlowLayout(spacing: 8) {
                                ForEach(strain.parents, id: \.self) { parent in
                                    lineageChip(parent, catalog: catalog)
                                }
                            }
                            if strain.lineageReported {
                                Label("Reported lineage. Sources disagree or it is unconfirmed.", systemImage: "info.circle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if !children.isEmpty {
                            if !strain.parents.isEmpty {
                                Text("Used in").font(.subheadline.weight(.semibold)).padding(.top, 4)
                            }
                            FlowLayout(spacing: 8) {
                                ForEach(children) { child in
                                    NavigationLink(value: child) { chip(child.name, linked: true) }
                                        .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .glassCard()
                    .appearLift(delay: 0.05)
                }

                if !(strain.effects.isEmpty && strain.downsides.isEmpty && strain.flavors.isEmpty && strain.terpenes.isEmpty) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Commonly reported").font(.headline)
                        if !strain.effects.isEmpty { TagCloud(tags: strain.effects.map { ($0, nil) }, hue: Theme.leafMid) }
                        if !strain.downsides.isEmpty { TagCloud(tags: strain.downsides.map { ($0, nil) }, hue: .orange) }
                        if !strain.flavors.isEmpty { TagCloud(tags: strain.flavors.map { ($0, nil) }, hue: .teal) }
                        if !strain.terpenes.isEmpty {
                            Text("Terpenes: \(strain.terpenes.map { ExperienceTags.label(for: $0) }.joined(separator: ", "))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text("What other people reported for this strain in general, not your bag. Genetics differ by grower and batch.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .glassCard()
                    .appearLift(delay: 0.1)
                }

                if !yours.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your bags").font(.headline)
                        ForEach(yours) { bag in
                            NavigationLink(value: bag.id) { BagRow(bag: bag).contentShape(.rect) }
                                .buttonStyle(.plain)
                        }
                    }
                    .glassCard()
                }

                let sources = model.strainSources.resolve(strain.sourceIDs)
                if !sources.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sources").font(.headline)
                        Text("Where the lineage, aliases and type come from. Each opens the breeder's or publisher's page in Safari.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(sources) { source in
                            if let url = source.url {
                                SafeLinkButton(title: source.title, systemImage: "link", address: url,
                                               detail: String(localized: "This opens \(source.host ?? String(localized: "the source")) in Safari. Taima itself sends nothing."))
                                    .frame(minHeight: 44, alignment: .leading)
                            } else {
                                Label(source.title, systemImage: "text.book.closed")
                                    .frame(minHeight: 44, alignment: .leading)
                            }
                        }
                    }
                    .glassCard()
                }

                Text(sourceNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(GlowBackground())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                let wished = model.isWished(strain)
                Button(wished ? String(localized: "Remove from want to try") : String(localized: "Want to try"), systemImage: wished ? "heart.fill" : "heart") {
                    withAnimation(.snappy) { model.toggleWish(strain) }
                }
                .symbolEffect(.bounce, value: wished)
            }
        }
        .sensoryFeedback(.selection, trigger: model.isWished(strain))
    }

    private var sourceNote: String {
        var parts: [String] = []
        if strain.isCurated { parts.append(String(localized: "Lineage, aliases and type: Taima's curated list.")) }
        if strain.isCommunity { parts.append(String(localized: "Tags: \(model.strainCatalog.communitySource).")) }
        return parts.joined(separator: " ")
    }

    @ViewBuilder private func lineageChip(_ name: String, catalog: StrainCatalog) -> some View {
        if let parent = catalog.info(named: name) {
            NavigationLink(value: parent) { chip(parent.name, linked: true) }
                .buttonStyle(.plain)
        } else {
            chip(name, linked: false)
        }
    }

    private func chip(_ text: String, linked: Bool) -> some View {
        HStack(spacing: 4) {
            Text(text)
            if linked { Image(systemName: "chevron.right").font(.caption2.weight(.semibold)) }
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(minHeight: linked ? 44 : nil)
        .foregroundStyle(linked ? AnyShapeStyle(Theme.leaf) : AnyShapeStyle(.primary))
        .background(linked ? AnyShapeStyle(Theme.leafMid.opacity(0.14)) : AnyShapeStyle(.fill.tertiary), in: .capsule)
        .contentShape(.capsule)
    }
}

/// A link from a bag or your strain to the library, when the name matches.
struct LibraryLink: View {
    @Environment(AppModel.self) private var model
    let productName: String

    /// Whether there is anything to show, so callers can skip an empty row.
    static func hasContent(for name: String, in catalog: StrainCatalog) -> Bool {
        catalog.match(productName: name) != nil || !catalog.crossParents(in: name).isEmpty
    }

    var body: some View {
        let catalog = model.strainCatalog
        let match = catalog.match(productName: productName)
        let crosses = catalog.crossParents(in: productName)
        VStack(alignment: .leading, spacing: 8) {
            if let match {
                NavigationLink(value: match.info) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("About \(match.info.name)").font(.subheadline.weight(.semibold))
                            Text(match.match == .partial ? String(localized: "Probably this strain, judging by the name") : String(localized: "From the strain library"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "books.vertical")
                    }
                }
            }
            if !crosses.isEmpty {
                Label("The name says it's a cross: \(crosses.joined(separator: " × "))", systemImage: "arrow.triangle.merge")
                    .font(.subheadline)
            }
        }
    }
}
