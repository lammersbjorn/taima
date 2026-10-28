import Foundation
import Testing
@testable import TaimaCore

@Suite struct LookupTests {
    let bags = [
        Bag(name: "Cali Mix", productID: "prd-00000000-0000-4000-8000-000000000103", sku: "LB-CALIMIX-05"),
        Bag(name: "COG Selection Indica", ean: "8721098003880"),
        Bag(name: "Girl Scout Cookie")
    ]

    @Test func exactPackage() {
        guard case .sameBag(let bag) = CollectionLookup.find(payloads: ["PRD-00000000-0000-4000-8000-000000000103"], texts: [], in: bags) else {
            Issue.record("expected the same bag"); return
        }
        #expect(bag.name == "Cali Mix")
    }

    @Test func sameProductLine() {
        guard case .sameProduct(let found) = CollectionLookup.find(payloads: ["8721098003880", "PRD-00000000-0000-4000-8000-000000000000"], texts: [], in: bags) else {
            Issue.record("expected the same product"); return
        }
        #expect(found.map(\.name) == ["COG Selection Indica"])
    }

    @Test func strainThroughLibraryAlias() {
        let catalog = StrainCatalog(curated: Data(#"{"strains":[{"n":"Girl Scout Cookies","a":["GSC","Girl Scout Cookie"]}]}"#.utf8), community: nil)
        let result = CollectionLookup.find(payloads: [], texts: ["THC 24%", "GSC"], in: bags, catalog: catalog)
        guard case .sameStrain(let name, let found) = result else { Issue.record("expected the strain"); return }
        #expect(name == "Girl Scout Cookies")
        #expect(found.count == 1)
    }

    @Test func newBag() {
        #expect(CollectionLookup.find(payloads: ["PRD-x"], texts: ["Speak Special"], in: bags) == .new)
    }
}
