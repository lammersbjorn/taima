import Foundation
import Testing
@testable import TaimaCore

@Suite struct LocalizationTests {
    @Test(arguments: ProductForm.allCases)
    func csvUsesStableEnglishForms(_ form: ProductForm) throws {
        var bag = Bag(name: "Test", strainType: .hybrid, stock: .full, form: form)
        bag.positiveEffects = ["Relaxed", "Mijn eigen tag"]
        // Resolve display values as the UI does, then round-trip the actual data.
        _ = form.label
        _ = bag.stock.label
        _ = bag.positiveEffects.map { ExperienceTags.label(for: $0) }
        let csv = CSVExport.make([bag])
        let columns = try #require(csv.split(separator: "\n").last).split(separator: ",", omittingEmptySubsequences: false)
        #expect(columns[2] == Substring(form.exportLabel))
        #expect(columns[3] == "Hybrid")
        #expect(columns[7] == "Full")
        let imported = try #require(CSVExport.parse(csv).first)
        #expect(imported.form == form)
        #expect(imported.positiveEffects == ["Relaxed", "Mijn eigen tag"])
        let restored = try CollectionBackup.decode(CollectionBackup(bags: [bag], photos: [:]).encoded())
        #expect(restored.bags.first?.productForm?.rawValue == form.rawValue)
        #expect(restored.bags.first?.positiveEffects == bag.positiveEffects)
    }

    @Test func widgetSnapshotsKeepRawNames() {
        let bag = Bag(name: "", stock: .open)
        let snapshot = WidgetSnapshot(bags: [bag], hasThumbnail: false, currentID: bag.id)
        #expect(snapshot.latest?.name == (snapshot.discreet ? "Latest bag" : ""))
        #expect(snapshot.current?.name == (snapshot.discreet ? "Bag in use" : ""))
    }

    @Test func customTagsAreDisplayedAsEntered() {
        #expect(ExperienceTags.label(for: "Mijn eigen tag") == "Mijn eigen tag")
        #expect(ExperienceTags.positive.contains("Relaxed"))
        #expect(ExperienceTags.negative.contains("Dry mouth"))
    }
}
