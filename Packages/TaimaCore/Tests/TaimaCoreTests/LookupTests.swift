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

@Suite(.serialized) struct GrowerLibraryTests {
    private var bundledFile: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appending(path: "../../../../App/Taima/Resources/growers.json").standardized
    }

    @Test func bundledFileMatchesTheBuiltInList() throws {
        defer { GrowerDirectory.reset() }
        #expect(GrowerDirectory.load(try Data(contentsOf: bundledFile)))
        #expect(GrowerDirectory.known == GrowerDirectory.builtIn)
    }

    @Test func downloadAddsAndReplacesGrowers() throws {
        defer { GrowerDirectory.reset() }
        var list = GrowerDirectory.builtIn
        list[0].aliases.append("aardachtig organics")
        list.append(.init(name: "Example Brand", aliases: ["example brand"], keys: ["domain:example.nl"], designated: false))
        #expect(GrowerDirectory.load(GrowerDirectory.encode(list)))
        #expect(GrowerDirectory.match(keys: ["domain:example.nl"], text: "") == "Example Brand")
        #expect(GrowerDirectory.designated.count == 10)
        #expect(GrowerDirectory.known.count == 11)
    }

    @Test(arguments: [
        #"{"growers":[{"name":"X","aliases":["Upper"],"keys":[]}]}"#,
        #"{"growers":[{"name":"X","aliases":["x"],"keys":["http:evil"]}]}"#,
        #"{"growers":[]}"#,
        "not json",
    ])
    func malformedDownloadsChangeNothing(_ json: String) {
        defer { GrowerDirectory.reset() }
        #expect(!GrowerDirectory.load(Data(json.utf8)))
        #expect(GrowerDirectory.known == GrowerDirectory.builtIn)
    }
}
