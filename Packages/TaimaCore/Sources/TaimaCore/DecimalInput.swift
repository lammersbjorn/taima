import Foundation

/// User-entered amounts use one locale's separator and never infer grouping.
/// Portable files use their own invariant number syntax instead.
public enum DecimalInput {
    public static func parse(_ text: String, locale: Locale) -> Double? {
        let separator = locale.decimalSeparator ?? "."
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = value.components(separatedBy: separator)
        guard parts.count <= 2, parts.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy({ (48...57).contains($0) }) }),
              let number = Double(value.replacingOccurrences(of: separator, with: ".")), number.isFinite
        else { return nil }
        return number
    }
}
