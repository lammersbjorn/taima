import Foundation

/// Growers that can be named from what a label prints. Only identifiers that
/// were seen on real labels are listed; everything else is learned when the
/// person names a producer (see `BagStore.remember`).
public enum GrowerDirectory {
    public struct Grower: Sendable, Hashable {
        public var name: String
        public var aliases: [String]
        public var keys: [String]
    }

    /// The ten designated experiment growers (watisnederhasj.nl and
    /// cannabisindustrie.nl, 2024–2026), with brand names as aliases.
    /// Phone, domain and EAN keys come from published label photos: COG
    /// pouches are on Canadelaar's own downloads page, and COG labels print
    /// +31 181 72 91 31.
    public static let known: [Grower] = [
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
