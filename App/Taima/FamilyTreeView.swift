import SwiftUI
import TaimaCore

/// Two generations up and one down from a strain, from the curated lineage.
struct FamilyTreeView: View {
    @Environment(AppModel.self) private var model
    let strain: StrainInfo

    var body: some View {
        let catalog = model.strainCatalog
        let parents = strain.parents
        let grandparents = parents.map { name in catalog.info(named: name)?.parents ?? [] }
        let children = catalog.children(of: strain)
        ScrollView {
            VStack(spacing: 0) {
                if grandparents.contains(where: { !$0.isEmpty }) {
                    level(String(localized: "Grandparents")) {
                        ForEach(Array(zip(parents, grandparents)), id: \.0) { parent, theirs in
                            if !theirs.isEmpty {
                                VStack(spacing: 6) {
                                    FlowLayout(spacing: 6) {
                                        ForEach(theirs, id: \.self) { node($0, small: true) }
                                    }
                                    Text("parents of \(parent)").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    connector
                }
                if !parents.isEmpty {
                    level(strain.isCross ? String(localized: "Crossed from") : String(localized: "Parent")) {
                        ForEach(parents, id: \.self) { node($0, small: false) }
                    }
                    connector
                }
                VStack(spacing: 6) {
                    Text(strain.name)
                        .font(.title3.bold())
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Theme.solid, in: .capsule)
                        .foregroundStyle(.white)
                    if strain.lineageReported, !strain.parents.isEmpty {
                        Text("Reported lineage").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
                if !children.isEmpty {
                    connector
                    level(String(localized: "Crossed into")) {
                        ForEach(children) { node($0.name, small: false) }
                    }
                }
                if parents.isEmpty && children.isEmpty {
                    ContentUnavailableView("No lineage known", systemImage: "arrow.triangle.merge", description: Text("Taima only lists lineages that are widely published."))
                        .padding(.top, 40)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .background(GlowBackground())
        .navigationTitle("Family tree")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var connector: some View {
        Rectangle()
            .fill(Theme.leafMid.opacity(0.4))
            .frame(width: 2, height: 26)
    }

    private func level<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 10) {
            Text(title).font(.headline)
            FlowLayout(spacing: 8) { content() }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .glassCard(padding: 0)
    }

    @ViewBuilder private func node(_ name: String, small: Bool) -> some View {
        let known = model.strainCatalog.info(named: name)
        let label = HStack(spacing: 4) {
            Text(known?.name ?? name)
            if known != nil { Image(systemName: "chevron.right").font(.caption2.weight(.semibold)) }
        }
        .font(small ? .caption : .subheadline.weight(.medium))
        .padding(.horizontal, small ? 8 : 12)
        .padding(.vertical, small ? 5 : 8)
        .foregroundStyle(known != nil ? AnyShapeStyle(Theme.leaf) : AnyShapeStyle(.primary))
        .background(known != nil ? AnyShapeStyle(Theme.leafMid.opacity(0.14)) : AnyShapeStyle(.fill.tertiary), in: .capsule)
        .frame(minHeight: 44)
        .contentShape(.rect)
        if let known {
            NavigationLink(value: known) { label }.buttonStyle(.plain)
        } else {
            label
        }
    }
}
