import SwiftUI
import TaimaCore

/// Opens a web address read from a label only after asking, and only over
/// https: label text comes from the camera and is not trusted.
struct SafeLinkButton: View {
    @Environment(\.openURL) private var openURL
    let title: String
    let systemImage: String
    let address: String
    var detail = String(localized: "This opens the address printed on the label in Safari. Taima itself sends nothing.")
    @State private var confirming = false

    static func validated(_ address: String) -> URL? {
        guard let url = URL(string: address.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.lowercased() == "https", url.host() != nil else { return nil }
        return url
    }

    var body: some View {
        if let url = Self.validated(address) {
            Button(title, systemImage: systemImage) { confirming = true }
                .confirmationDialog("Open \(url.host() ?? String(localized: "this website"))?", isPresented: $confirming, titleVisibility: .visible) {
                    Button("Open in Safari") { openURL(url) }
                } message: {
                    Text(detail)
                }
        }
    }
}

enum ProductCodeLookup {
    /// The Potspot page for a product code, only for well-formed PRD codes.
    static func url(for productID: String) -> URL? {
        let id = productID.lowercased()
        guard id.range(of: #"^prd-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"#, options: .regularExpression) != nil else { return nil }
        return URL(string: "https://www.potspot.nl/product-code/\(id)")
    }
}

extension UIPasteboard {
    /// Copies only to this iPhone (no Universal Clipboard) and clears after
    /// ten minutes.
    static func copyPrivately(_ text: String) {
        UIPasteboard.general.setItems([["public.utf8-plain-text": text]], options: [
            .localOnly: true,
            .expirationDate: Date.now.addingTimeInterval(600)
        ])
    }
}
