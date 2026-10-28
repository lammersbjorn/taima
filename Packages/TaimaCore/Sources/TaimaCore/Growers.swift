import Foundation
import Synchronization

/// Growers that can be named from what a label prints. Only identifiers that
/// were seen on real labels are listed; everything else is learned when the
/// person names a producer (see `BagStore.remember`).
public enum GrowerDirectory {
    public struct Grower: Sendable, Hashable, Codable {
        public var name: String
        public var aliases: [String]
        public var keys: [String]
        /// One of the experiment's designated growers; brands and later
        /// additions can be listed without counting towards "All ten".
        public var designated: Bool?

        public init(name: String, aliases: [String], keys: [String], designated: Bool? = true) {
            self.name = name
            self.aliases = aliases
            self.keys = keys
            self.designated = designated
        }
    }

    /// The growers in use: the built-in list, updated by the library download.
    public static var known: [Grower] { downloaded.withLock { $0 } ?? builtIn }

    /// The designated growers, for milestones.
    public static var designated: [Grower] { known.filter { $0.designated ?? true } }

    private static let downloaded = Mutex<[Grower]?>(nil)

    private struct File: Codable { var growers: [Grower] }

    /// Applies a downloaded growers.json: entries replace built-in growers
    /// with the same name and add new ones. Malformed data changes nothing.
    @discardableResult
    public static func load(_ data: Data?) -> Bool {
        guard let data, let file = try? JSONDecoder().decode(File.self, from: data) else { return false }
        let valid = file.growers.filter { grower in
            !grower.name.trimmingCharacters(in: .whitespaces).isEmpty
                && grower.aliases.allSatisfy { $0 == $0.lowercased() && !$0.isEmpty }
                && grower.keys.allSatisfy { $0.range(of: #"^(domain|tel|ean):[a-z0-9.-]+$"#, options: .regularExpression) != nil }
        }
        guard !valid.isEmpty, valid.count == file.growers.count else { return false }
        var merged = builtIn
        for grower in valid {
            if let index = merged.firstIndex(where: { $0.name == grower.name }) { merged[index] = grower } else { merged.append(grower) }
        }
        downloaded.withLock { $0 = merged }
        return true
    }

    /// Back to the built-in list, for tests.
    public static func reset() { downloaded.withLock { $0 = nil } }

    /// Encodes a list as growers.json, for publishing.
    public static func encode(_ growers: [Grower]) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(File(growers: growers))
    }

    /// The ten designated experiment growers (watisnederhasj.nl and
    /// cannabisindustrie.nl, 2024–2026), with brand names as aliases.
    /// Phone, domain and EAN keys come from published label photos: COG
    /// pouches are on Canadelaar's own downloads page, and COG labels print
    /// +31 181 72 91 31.
    public static let builtIn: [Grower] = [
        Grower(name: "Aardachtig Organics", aliases: ["aardachtig"], keys: ["domain:aardachtig.nl", "tel:852738149"]),
        Grower(name: "Canadelaar", aliases: ["canadelaar", "c o g", "co g", "cog"], keys: ["tel:181729131", "ean:8721098"]),
        Grower(name: "FYTA", aliases: ["fyta", "fyta group"], keys: ["domain:fyta.group", "tel:416237000"]),
        Grower(name: "Holigram", aliases: ["holigram", "grassmeijers"], keys: ["domain:holigram.nl"]),
        Grower(name: "Hollandse Hoogtes", aliases: ["hollandse hoogtes"], keys: ["domain:hollandsehoogtes.nl"]),
        Grower(name: "Legacy Brands", aliases: ["legacy brands"], keys: []),
        Grower(name: "Village Farms Netherlands", aliases: ["village farms", "leli holland", "leli"], keys: ["domain:leliholland.nl"]),
        Grower(name: "Linsboer (The Plug)", aliases: ["linsboer", "the plug"], keys: []),
        Grower(name: "The Growery", aliases: ["the growery", "growery"], keys: []),
        Grower(name: "Q-Farms", aliases: ["q-farms", "q farms", "qfarms", "qati"], keys: [])
    ]

    public static var names: [String] { known.map(\.name) }

    /// A known grower whose identifier or name appears on the label.
    public static func match(keys: [String], text: String) -> String? {
        let lower = text.lowercased()
        return known.first { grower in
            grower.keys.contains(where: keys.contains) || grower.aliases.contains { alias in
                // Whole words only: "cog" must not match "cognac".
                lower.range(of: "\\b" + NSRegularExpression.escapedPattern(for: alias) + "\\b", options: .regularExpression) != nil
            }
        }?.name
    }

    /// Back labels name the grower after words like "Teler:" or "Geteeld door".
    public static func labelledGrower(in lines: [String]) -> String? {
        let label = #"(?:teler|kweker|producent|producer|grower|teelt|geteeld\s+door|gekweekt\s+door|geproduceerd\s+door|vervaardigd\s+door|verpakt\s+door|grown\s+by|produced\s+by)"#
        let pattern = #"(?i)\b"# + label + #"(?:\s*[/&]\s*"# + label + #")?\s*[:.]?\s*(.*)$"#
        func clean(_ text: String) -> String? {
            let value = text.components(separatedBy: CharacterSet(charactersIn: "|;"))[0]
                .replacingOccurrences(of: #"(?i)\s+(?:tel[.:]|www\.|adres:).*$"#, with: "", options: .regularExpression)
            let cleaned = LabelParser.cleanName(value)
            guard cleaned.filter(\.isLetter).count >= 3, cleaned.count <= 48,
                  cleaned.range(of: #"(?i)\b(?:THC|CBD|gewicht|geoogst|verpakt|houdbaar|THT|postbus|ingrediënten)\b"#, options: .regularExpression) == nil,
                  !cleaned.contains("%"), !cleaned.contains("@"), !cleaned.hasPrefix("www.") else { return nil }
            return match(keys: [], text: cleaned) ?? cleaned
        }
        for (index, line) in lines.enumerated() {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else { continue }
            let value = (line as NSString).substring(with: match.range(at: 1))
            if let name = clean(value) { return name }
            if value.isEmpty, index + 1 < lines.count, let name = clean(lines[index + 1]) { return name }
            let prefix = (line as NSString).substring(to: match.range.location)
            if prefix.contains("|") || prefix.contains(":") || prefix.contains(";") {
                if let name = clean(prefix) { return name }
            }
        }
        for line in lines where line.range(of: #"(?i)\bB\.?\s?V\.?$"#, options: .regularExpression) != nil {
            if let name = clean(line) { return name }
        }
        return nil
    }

}

public extension LabelReading {
    /// Fills what the front left empty with what the back says. The front
    /// wins where both have a value: it carries the bag-specific print.
    func merged(withBack back: LabelReading) -> LabelReading {
        var merged = self
        merged.name = name ?? back.name
        merged.producer = producer ?? back.producer
        merged.strainType = strainType ?? back.strainType
        merged.thc = thc ?? back.thc
        merged.cbd = cbd ?? back.cbd
        merged.grams = grams ?? back.grams
        merged.harvestedOn = harvestedOn ?? back.harvestedOn
        merged.packedOn = packedOn ?? back.packedOn
        merged.bestBeforeOn = bestBeforeOn ?? back.bestBeforeOn
        merged.productID = productID ?? back.productID
        merged.sku = sku ?? back.sku
        merged.ean = ean ?? back.ean
        merged.leafletURL = leafletURL ?? back.leafletURL
        merged.form = form ?? back.form
        merged.unitCount = unitCount ?? back.unitCount
        for field in back.detectedFields where !detectedFields.contains(field) {
            merged.confidence[field] = back.confidence[field]
        }
        merged.producerKeys = producerKeys + back.producerKeys.filter { !producerKeys.contains($0) }
        return merged
    }
}
