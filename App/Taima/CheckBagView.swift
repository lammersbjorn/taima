import SwiftUI
import TaimaCore
import VisionKit

/// Point the camera at a bag in the shop: Taima says whether you already
/// have it, or how you rated the same product or strain.
struct CheckBagView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var payloads: [String] = []
    @State private var texts: [String] = []
    @State private var result = CollectionLookup.Result.new
    @State private var seenSomething = false

    var body: some View {
        ZStack(alignment: .bottom) {
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                LiveScanner { codes, lines in
                    payloads = codes
                    texts = lines
                    if !codes.isEmpty || !lines.isEmpty { seenSomething = true }
                    let next = CollectionLookup.find(payloads: codes, texts: lines, in: model.bags, catalog: model.strainCatalog)
                    if next != result {
                        withAnimation(.spring(duration: 0.35)) { result = next }
                    }
                }
                .ignoresSafeArea()
            } else {
                ContentUnavailableView("Live scanning isn't available", systemImage: "camera.badge.ellipsis", description: Text("This needs camera access and an iPhone that supports live text."))
            }
            ResultCard(result: result, seenSomething: seenSomething)
                .padding()
        }
        .overlay(alignment: .topTrailing) {
            Button("Close", systemImage: "xmark") { dismiss() }
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .controlSize(.large)
                .padding()
        }
        .sensoryFeedback(.success, trigger: result) { _, new in
            if case .new = new { return false }
            return true
        }
    }
}

private struct ResultCard: View {
    let result: CollectionLookup.Result
    let seenSomething: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(hue)
                .frame(width: 34)
                .contentTransition(.symbolEffect(.replace))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(hue.opacity(0.15)), in: .rect(cornerRadius: 24))
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch result {
        case .sameBag: "checkmark.seal.fill"
        case .sameProduct: "arrow.triangle.2.circlepath"
        case .sameStrain: "leaf.fill"
        case .new: seenSomething ? "sparkles" : "viewfinder"
        }
    }

    private var hue: Color {
        switch result {
        case .sameBag: .orange
        case .sameProduct, .sameStrain: Theme.leafMid
        case .new: .secondary
        }
    }

    private var title: String {
        switch result {
        case .sameBag: "You already have this bag"
        case .sameProduct(let bags): "You've had this product \(bags.count == 1 ? "once" : "\(bags.count) times")"
        case .sameStrain(let name, let bags): "You've had \(name) \(bags.count == 1 ? "once" : "\(bags.count) times")"
        case .new: seenSomething ? "New to you" : "Point at the label"
        }
    }

    private var detail: String {
        switch result {
        case .sameBag(let bag): "\(bag.displayName), added \(bag.collectedOn.formatted(date: .abbreviated, time: .omitted)). The product code matches."
        case .sameProduct(let bags), .sameStrain(_, let bags): summary(bags)
        case .new: seenSomething ? "Nothing in your collection matches this code or name." : "Hold the QR code or the name in view. Nothing is saved or sent."
        }
    }

    private func summary(_ bags: [Bag]) -> String {
        let scores = bags.compactMap(\.rating10)
        var parts: [String] = []
        let verdicts = bags.compactMap(\.wouldBuyAgain)
        if let last = verdicts.last {
            parts.append(last ? "you'd buy it again" : "you said you wouldn't buy it again")
        }
        if !scores.isEmpty {
            parts.append("Your score: \((scores.reduce(0, +) / Double(scores.count)).formatted(.number.precision(.fractionLength(0...1)))) / 10")
        }
        let effects = Array(Set(bags.flatMap(\.positiveEffects))).prefix(3)
        if !effects.isEmpty { parts.append(effects.joined(separator: ", ").lowercased()) }
        let downsides = Array(Set(bags.flatMap(\.negativeEffects))).prefix(2)
        if !downsides.isEmpty { parts.append("watch out: " + downsides.joined(separator: ", ").lowercased()) }
        return parts.isEmpty ? "Last one: \(bags[0].displayName)." : parts.joined(separator: " · ")
    }
}

/// VisionKit's live scanner, reporting every code payload and text line in view.
private struct LiveScanner: UIViewControllerRepresentable {
    let onChange: ([String], [String]) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr, .dataMatrix, .ean13, .ean8, .code128]), .text()],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        if !scanner.isScanning { try? scanner.startScanning() }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onChange: ([String], [String]) -> Void

        init(onChange: @escaping ([String], [String]) -> Void) {
            self.onChange = onChange
        }

        func dataScanner(_ scanner: DataScannerViewController, didAdd added: [RecognizedItem], allItems: [RecognizedItem]) { report(allItems) }
        func dataScanner(_ scanner: DataScannerViewController, didUpdate updated: [RecognizedItem], allItems: [RecognizedItem]) { report(allItems) }
        func dataScanner(_ scanner: DataScannerViewController, didRemove removed: [RecognizedItem], allItems: [RecognizedItem]) { report(allItems) }

        private func report(_ items: [RecognizedItem]) {
            var codes: [String] = []
            var lines: [String] = []
            for item in items {
                switch item {
                case .barcode(let code): if let payload = code.payloadStringValue { codes.append(payload) }
                case .text(let text): lines.append(text.transcript)
                @unknown default: break
                }
            }
            onChange(codes, lines)
        }
    }
}
