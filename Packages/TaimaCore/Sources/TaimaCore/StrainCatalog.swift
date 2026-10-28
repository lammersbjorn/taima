import Foundation

/// What Taima knows about a strain from its bundled libraries. It describes
/// the strain in general, never the bag: genetics vary by grower and batch.
public struct StrainInfo: Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var aliases: [String]
    public var type: StrainType?
    /// How the strain is usually described, e.g. "Sativa-leaning".
    public var lean: String?
    public var parents: [String]
    /// The lineage is disputed or unconfirmed.
    public var lineageReported: Bool
    public var breeder: String?
    /// References defined in docs/research/strain-sources.md, bundled as metadata.
    public var sourceIDs: [String]
    public var effects: [String]
    public var downsides: [String]
    public var flavors: [String]
    public var terpenes: [String]
    public var isCurated: Bool
    public var isCommunity: Bool

    /// The type to show. The community data labels most strains "Hybrid" by
    /// default, so that answer only counts when the curated list agrees.
    public var trustedType: StrainType? {
        if isCurated { return type }
        return type == .hybrid ? nil : type
    }

    public var isCross: Bool { parents.count >= 2 }
}

public final class StrainCatalog: Sendable {
    public enum Match: Sendable, Equatable { case exact, alias, partial }

    public let strains: [StrainInfo]
    public let communitySource: String
    public let curatedSource: String
    private let byKey: [String: Int]
    private let aliasKey: [String: Int]
    private let childrenByKey: [String: [Int]]

    /// Words on Dutch experiment labels that are brands or cuts, not strains.
    static let noise: Set<String> = [
        "cog", "bio", "r", "d", "rd", "exclusive", "selection", "hand", "trim", "trimmed",
        "master", "cut", "hq", "edition", "pre", "roll", "rolls", "preroll", "prerolls",
        "hasj", "hash", "organics", "organic", "the", "plug", "gram", "g", "pheno", "hunt"
    ]

    /// Library entries named after a category; never a match on their own.
    static let generic: Set<String> = [
        "indica", "sativa", "hybrid", "kush", "haze", "skunk", "mix", "special", "classic",
        "cookies", "og", "cheese", "jack", "critical", "sherbet", "amnesia"
    ]

    public init(curated: Data?, community: Data?) {
        struct File: Decodable {
            struct Entry: Decodable {
                var n: String
                var a: [String]?
                var t: String?
                var lean: String?
                var p: [String]?
                var r: Bool?
                var b: String?
                var src: [String]?
                var e: [String]?
                var d: [String]?
                var f: [String]?
                var tp: [String]?
            }
            var source: String?
            var strains: [Entry]
        }
        let decoder = JSONDecoder()
        let curatedFile = curated.flatMap { try? decoder.decode(File.self, from: $0) }
        let communityFile = community.flatMap { try? decoder.decode(File.self, from: $0) }
        curatedSource = curatedFile?.source ?? ""
        communitySource = communityFile?.source ?? ""

        func type(_ text: String?) -> StrainType? { text.flatMap { StrainType(rawValue: $0.lowercased()) } }

        var merged: [String: StrainInfo] = [:]
        for entry in communityFile?.strains ?? [] {
            let key = StrainGroup.key(for: entry.n)
            merged[key] = StrainInfo(
                id: key, name: entry.n, aliases: [], type: type(entry.t), lean: nil, parents: [],
                lineageReported: false, breeder: entry.b, sourceIDs: [], effects: entry.e ?? [], downsides: entry.d ?? [],
                flavors: entry.f ?? [], terpenes: entry.tp ?? [], isCurated: false, isCommunity: true
            )
        }
        for entry in curatedFile?.strains ?? [] {
            let key = StrainGroup.key(for: entry.n)
            // Curated lineage, aliases, type and breeder credit win. An absent
            // breeder must not inherit an unreviewed community shop name.
            let aliasKeys = (entry.a ?? []).map(StrainGroup.key(for:))
            let community = merged[key] ?? aliasKeys.lazy.compactMap { merged[$0] }.first
            for alias in aliasKeys where merged[alias]?.isCurated == false { merged[alias] = nil }
            merged[key] = StrainInfo(
                id: key, name: entry.n, aliases: entry.a ?? [], type: type(entry.t), lean: entry.lean,
                parents: entry.p ?? [], lineageReported: entry.r ?? false,
                breeder: entry.b, sourceIDs: entry.src ?? [], effects: community?.effects ?? [],
                downsides: community?.downsides ?? [], flavors: community?.flavors ?? [],
                terpenes: community?.terpenes ?? [], isCurated: true, isCommunity: community != nil
            )
        }
        strains = merged.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        var byKey: [String: Int] = [:]
        var aliasKey: [String: Int] = [:]
        var children: [String: [Int]] = [:]
        for (index, strain) in strains.enumerated() {
            byKey[strain.id] = index
            for alias in strain.aliases { aliasKey[StrainGroup.key(for: alias)] = index }
            for parent in strain.parents { children[StrainGroup.key(for: parent), default: []].append(index) }
        }
        self.byKey = byKey
        self.aliasKey = aliasKey
        self.childrenByKey = children
    }

    public func info(named name: String) -> StrainInfo? {
        let key = StrainGroup.key(for: name)
        if let index = byKey[key] ?? aliasKey[key] { return strains[index] }
        return nil
    }

    /// Strains that list this one as a parent.
    public func children(of strain: StrainInfo) -> [StrainInfo] {
        let keys = [strain.id] + strain.aliases.map(StrainGroup.key(for:))
        var seen = Set<String>()
        return keys.flatMap { childrenByKey[$0] ?? [] }.map { strains[$0] }.filter { seen.insert($0.id).inserted }
    }

    /// The strain a product name refers to, ignoring brand and cut words:
    /// "COG Amnesia Haze Master Cut" is Amnesia Haze.
    public func match(productName: String) -> (info: StrainInfo, match: Match)? {
        let key = StrainGroup.key(for: productName)
        if let index = byKey[key] { return (strains[index], .exact) }
        if let index = aliasKey[key] { return (strains[index], .alias) }
        let tokens = key.split(separator: " ").map(String.init).filter { !Self.noise.contains($0) }
        guard !tokens.isEmpty else { return nil }
        // Longest run of words that names a strain; single short words are too vague.
        for length in stride(from: tokens.count, through: 1, by: -1) {
            for start in 0...(tokens.count - length) {
                let candidate = tokens[start..<(start + length)].joined(separator: " ")
                if length == 1, Self.generic.contains(candidate) { continue }
                let index = byKey[candidate] ?? aliasKey[candidate]
                // A lone short word only counts when it is a curated name (GMO, GSC).
                guard let index, length > 1 || candidate.count >= 5 || strains[index].isCurated else { continue }
                return (strains[index], length == tokens.count && start == 0 ? .alias : .partial)
            }
        }
        return nil
    }

    /// Parents written in the product name itself: "Gmo x Zki", "A × B".
    public func crossParents(in productName: String) -> [String] {
        let parts = productName.components(separatedBy: CharacterSet(charactersIn: "×"))
            .flatMap { $0.components(separatedBy: " x ") }
            .flatMap { $0.components(separatedBy: " X ") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard parts.count >= 2 else { return [] }
        return parts.map { part in
            let cleaned = part.split(separator: " ").filter { !Self.noise.contains($0.lowercased()) }.joined(separator: " ")
            return match(productName: cleaned)?.info.name ?? cleaned
        }
    }

    /// Names and aliases starting with or containing the query, best first.
    public func search(_ query: String, limit: Int = 60) -> [StrainInfo] {
        let key = StrainGroup.key(for: query)
        guard !key.isEmpty else { return [] }
        var scored: [(Int, StrainInfo)] = []
        for strain in strains {
            let names = [strain.id] + strain.aliases.map(StrainGroup.key(for:))
            var score = Int.max
            for (position, name) in names.enumerated() {
                let penalty = position == 0 ? 0 : 1
                if name == key { score = min(score, 0 + penalty) }
                else if name.hasPrefix(key) { score = min(score, 2 + penalty) }
                else if name.contains(" " + key) { score = min(score, 4 + penalty) }
                else if name.contains(key) { score = min(score, 6 + penalty) }
            }
            if score != .max { scored.append((score - (strain.isCurated ? 1 : 0), strain)) }
        }
        return scored.sorted { ($0.0, $0.1.name.count) < ($1.0, $1.1.name.count) }.prefix(limit).map(\.1)
    }
}
