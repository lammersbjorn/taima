import Foundation

/// A complete, self-contained export: every bag plus its compressed photo.
public struct CollectionBackup: Codable, Sendable {
    public static let format = "taima-backup"
    public static let currentVersion = 1

    public var format: String
    public var version: Int
    public var exportedAt: Date
    public var bags: [Bag]
    /// Photo file name to file contents.
    public var photos: [String: Data]
    /// Optional so backups from before the wishlist still restore.
    public var wishlist: [WishItem]?

    public init(bags: [Bag], photos: [String: Data], wishlist: [WishItem] = [], exportedAt: Date = .now) {
        self.wishlist = wishlist
        self.format = Self.format
        self.version = Self.currentVersion
        self.exportedAt = exportedAt
        self.bags = bags
        self.photos = photos
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> CollectionBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(CollectionBackup.self, from: data)
        guard backup.format == format, backup.version <= currentVersion else {
            throw BackupError.unsupported
        }
        return backup
    }
}

public enum BackupError: Error, LocalizedError {
    case unsupported

    public var errorDescription: String? {
        String(localized: "This file is not a Taima backup, or it was made by a newer version.", bundle: .taimaLocalization)
    }
}

public enum CSVExport {
    // A portable file must not change with the device's display locale.
    private static func potency(_ value: Potency?) -> String {
        guard let value else { return "" }
        let number = value.percent.formatted(.number.locale(Locale(identifier: "en_US_POSIX"))
            .precision(.fractionLength(0...1)).grouping(.never))
        let lower = value.lowerBound.map { $0.formatted(.number.locale(Locale(identifier: "en_US_POSIX"))
            .precision(.fractionLength(0...1)).grouping(.never)) + "–" } ?? ""
        return (value.isUpperBound ? "<" : "") + lower + number + "%"
    }
    public static func make(_ bags: [Bag]) -> String {
        let day = Date.ISO8601FormatStyle().year().month().day()
        let header = ["name", "producer", "form", "type", "thc", "cbd", "grams", "stock", "remaining_g", "harvested", "packed", "collected",
                      "price_eur", "shop", "town", "score_of_10", "effects", "downsides", "flavours", "sessions", "product_id", "sku", "ean", "notes", "thc_mg_each"]
        let rows = bags.map { bag in
            [
                bag.name, bag.producer ?? "", bag.form.exportLabel, bag.strainType?.rawValue.capitalized ?? "", potency(bag.thc), potency(bag.cbd),
                bag.grams.map { String($0) } ?? "", bag.stock.rawValue.capitalized, bag.stock == .empty ? "" : String(bag.remaining),
                bag.harvestedOn.map { $0.formatted(day) } ?? "",
                bag.packedOn.map { $0.formatted(day) } ?? "", bag.collectedOn.formatted(day),
                bag.priceEuros.map { String($0) } ?? "", bag.shop ?? "", bag.shopCity ?? "",
                bag.rating10.map { String($0) } ?? "",
                bag.positiveEffects.joined(separator: "; "), bag.negativeEffects.joined(separator: "; "),
                bag.flavorTags.joined(separator: "; "), String(bag.usage.count),
                bag.productID ?? "", bag.sku ?? "", bag.ean ?? "", bag.notes,
                bag.thcMilligrams.map { String($0) } ?? ""
            ].map(escape).joined(separator: ",")
        }
        return ([header.joined(separator: ",")] + rows).joined(separator: "\n") + "\n"
    }

    /// Reads a CSV made by `make`, or a spreadsheet with the same headers.
    /// Unknown columns are ignored; rows without a name are skipped.
    public static func parse(_ text: String) -> [Bag] {
        // Excel's "CSV UTF-8" starts with a byte order mark, and with Dutch
        // settings it separates columns with semicolons.
        var text = text
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        let firstLine = text.prefix { $0 != "\n" && $0 != "\r\n" }
        let separator: Character = firstLine.filter { $0 == ";" }.count > firstLine.filter { $0 == "," }.count ? ";" : ","
        let rows = records(text, separator: separator)
        guard let header = rows.first?.map({ $0.lowercased().trimmingCharacters(in: .whitespaces) }) else { return [] }
        func value(_ row: [String], _ key: String) -> String? {
            guard let index = header.firstIndex(of: key), index < row.count else { return nil }
            var field = row[index].trimmingCharacters(in: .whitespaces)
            if field.hasPrefix("'") { field.removeFirst() }
            return field.isEmpty ? nil : field
        }
        func number(_ text: String?) -> Double? { text.flatMap { Double($0.replacingOccurrences(of: ",", with: ".")) } }
        func potency(_ text: String?) -> Potency? {
            guard let text else { return nil }
            let cleaned = text.replacingOccurrences(of: "%", with: "")
            guard let value = number(cleaned.replacingOccurrences(of: "<", with: "")) else { return nil }
            return Potency(percent: value, isUpperBound: cleaned.hasPrefix("<"))
        }
        func date(_ text: String?) -> Date? {
            text.flatMap { LabelParser.dates(in: $0).first ?? (try? Date($0, strategy: .iso8601.year().month().day())) }
        }
        func tags(_ text: String?) -> [String] { (text ?? "").split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        return rows.dropFirst().compactMap { row in
            guard let name = value(row, "name") else { return nil }
            var bag = Bag(name: name, producer: value(row, "producer"))
            bag.productForm = value(row, "form").flatMap { label in ProductForm.allCases.first { $0.exportLabel.caseInsensitiveCompare(label) == .orderedSame } }
            bag.strainType = value(row, "type").flatMap { StrainType(rawValue: $0.lowercased()) }
            bag.thc = potency(value(row, "thc"))
            bag.cbd = potency(value(row, "cbd"))
            bag.grams = number(value(row, "grams"))
            bag.harvestedOn = date(value(row, "harvested"))
            bag.packedOn = date(value(row, "packed"))
            bag.collectedOn = date(value(row, "collected")) ?? .now
            bag.priceEuros = number(value(row, "price_eur"))
            bag.shop = value(row, "shop")
            bag.shopCity = value(row, "town")
            bag.rating10 = number(value(row, "score_of_10") ?? value(row, "rating").flatMap { r in Double(r).map { String($0 * 2) } })
            bag.positiveEffects = tags(value(row, "effects"))
            bag.negativeEffects = tags(value(row, "downsides"))
            bag.flavorTags = tags(value(row, "flavours"))
            bag.productID = value(row, "product_id")
            bag.sku = value(row, "sku")
            bag.ean = value(row, "ean")
            bag.notes = value(row, "notes") ?? ""
            bag.thcMilligrams = number(value(row, "thc_mg_each"))
            bag.stock = .empty
            return bag
        }
    }

    /// RFC 4180 records: quoted fields may hold commas, quotes and newlines.
    static func records(_ text: String, separator: Character = ",") -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        var iterator = Array(text).makeIterator()
        var pending: Character? = nil
        while let character = pending ?? iterator.next() {
            pending = nil
            if quoted {
                if character == "\"" {
                    if let next = iterator.next() {
                        if next == "\"" { field.append("\"") } else { quoted = false; pending = next }
                    } else { quoted = false }
                } else {
                    field.append(character)
                }
            } else if character == "\"" {
                quoted = true
            } else if character == separator {
                row.append(field); field = ""
            } else if character == "\n" || character == "\r\n" || character == "\r" {
                row.append(field); field = ""
                if !(row.count == 1 && row[0].isEmpty) { rows.append(row) }
                row = []
            } else {
                field.append(character)
            }
        }
        if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
        return rows
    }

    static func escape(_ field: String) -> String {
        var field = field
        // A leading = + - @ makes spreadsheets run the cell as a formula.
        if let first = field.first, "=+-@\t\r".contains(first), Double(field) == nil {
            field = "'" + field
        }
        guard field.contains(where: { ",\"\n\r".contains($0) }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

