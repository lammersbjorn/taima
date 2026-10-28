import Foundation
import Testing
@testable import TaimaCore

private let curated = Data("""
{"source":"test","strains":[
 {"n":"Girl Scout Cookies","a":["GSC","Girl Scout Cookie"],"t":"Hybrid","p":["OG Kush","Durban Poison"]},
 {"n":"Gelato","t":"Hybrid","p":["Sunset Sherbet","Thin Mint Girl Scout Cookies"]},
 {"n":"Sunset Sherbet","t":"Hybrid","p":["Girl Scout Cookies","Pink Panties"]},
 {"n":"Amnesia Haze","a":["Amnesia"],"t":"Hybrid","lean":"Sativa-leaning","b":"Soma Seeds","src":["soma-amnesia-haze"]},
 {"n":"Snow White","a":["Sneeuwwitje","Sneeuwwietje"],"t":"Hybrid","lean":"Indica-leaning"}
]}
""".utf8)

private let community = Data("""
{"source":"kushy","strains":[
 {"n":"Amnesia Haze","t":"Hybrid","b":"Soma Seeds","e":["Happy"],"d":["Dry Mouth"],"f":["Citrus"]},
 {"n":"Amnesia","t":"Sativa","e":["Uplifted"]},
 {"n":"Zkittlez","t":"Indica","f":["Sweet"]},
 {"n":"Speak Easy","t":"Hybrid"}
]}
""".utf8)

@Suite struct StrainCatalogTests {
    let catalog = StrainCatalog(curated: curated, community: community)

    @Test func curatedWinsAndAliasesReplaceDuplicates() throws {
        let amnesia = try #require(catalog.info(named: "amnesia"))
        #expect(amnesia.name == "Amnesia Haze")
        #expect(amnesia.lean == "Sativa-leaning")
        #expect(amnesia.effects == ["Happy"])
        #expect(amnesia.breeder == "Soma Seeds")
        #expect(amnesia.sourceIDs == ["soma-amnesia-haze"])
        #expect(catalog.strains.filter { $0.name == "Amnesia" }.isEmpty)
    }

    @Test func productNamesMatch() {
        #expect(catalog.match(productName: "Girl Scout Cookie")?.info.name == "Girl Scout Cookies")
        #expect(catalog.match(productName: "COG Amnesia Haze Master Cut")?.info.name == "Amnesia Haze")
        #expect(catalog.match(productName: "COG Sneeuwwietje")?.info.name == "Snow White")
        #expect(catalog.match(productName: "Cali Mix") == nil)
        #expect(catalog.match(productName: "Speak Special") == nil)
    }

    @Test func lineageAndChildren() throws {
        let gsc = try #require(catalog.info(named: "GSC"))
        #expect(gsc.isCross)
        #expect(catalog.children(of: gsc).map(\.name) == ["Sunset Sherbet"])
    }

    @Test func communityHybridIsNotTrusted() throws {
        #expect(try #require(catalog.info(named: "Speak Easy")).trustedType == nil)
        #expect(try #require(catalog.info(named: "Zkittlez")).trustedType == .indica)
        #expect(try #require(catalog.info(named: "Gelato")).trustedType == .hybrid)
    }

    @Test func search() {
        #expect(catalog.search("gsc").first?.name == "Girl Scout Cookies")
        #expect(catalog.search("amn").first?.name == "Amnesia Haze")
        #expect(catalog.search("").isEmpty)
    }
}

/// Read the actual app resources so fixture-only tests cannot hide bad curation
/// or the accidental reintroduction of aliases that merge distinct strains.
@Suite struct BundledStrainCatalogTests {
    private func bundledCatalog() throws -> StrainCatalog {
        let resources = TestResources.app
        return try StrainCatalog(
            curated: Data(contentsOf: resources.appendingPathComponent("strains-curated.json")),
            community: Data(contentsOf: resources.appendingPathComponent("strains.json"))
        )
    }

    @Test(arguments: [
        ("COG Amnesia Haze Master Cut", "Amnesia Haze"),
        ("BIO Amnesia Original Hand Trim", "Amnesia"),
        ("COG Sneeuwwitje", "Snow White"),
        ("BIO Sneeuwwietje Hand Trim", "Snow White"),
        ("COG Superskunk", "Super Skunk"),
        ("COG Bubblegum", "Bubble Gum"),
        ("BIO Blueberry Cheese", "Blue Cheese"),
        ("COG LCG", "Lemon Cherry Gelato"),
        ("Gelato 33", "Gelato #33"),
        ("Gelato33", "Gelato #33"),
        ("BIO Gelato41 Hand Trim", "Gelato #41"),
        ("COG Original Z", "Zkittlez")
    ])
    func bundledAliasesMatch(product: String, strain: String) throws {
        #expect(try bundledCatalog().match(productName: product)?.info.name == strain)
    }

    @Test func separateSelectionsAndPreserveCommunityTags() throws {
        let catalog = try bundledCatalog()
        #expect(catalog.strains.filter(\.isCurated).count >= 150)
        #expect(catalog.strains.filter(\.isCurated).allSatisfy { !$0.sourceIDs.isEmpty })
        #expect(catalog.info(named: "Amnesia")?.id != catalog.info(named: "Amnesia Haze")?.id)
        #expect(catalog.info(named: "Gelato")?.id != catalog.info(named: "Gelato #33")?.id)
        #expect(catalog.info(named: "MAC")?.id != catalog.info(named: "MAC 1")?.id)
        #expect(catalog.match(productName: "COG Selection Indica") == nil)
        #expect(catalog.match(productName: "COG Kush Mix") == nil)
        #expect(try #require(catalog.info(named: "White Widow")).isCommunity)
        #expect(try #require(catalog.info(named: "Amnesia Haze")).flavors.contains("Citrus"))
        let z = try #require(catalog.info(named: "Zkittlez"))
        #expect(catalog.children(of: z).contains { $0.name == "Runtz Muffin" })
        #expect(catalog.search("Sneeuw").first?.name == "Snow White")
    }

    @Test func curatedBreederDoesNotInheritUnreviewedCommunityCredit() throws {
        let catalog = StrainCatalog(
            curated: Data(#"{"strains":[{"n":"Example","t":"Hybrid"}]}"#.utf8),
            community: Data(#"{"strains":[{"n":"Example","b":"A shop, not the breeder","e":["Happy"]}]}"#.utf8)
        )
        let strain = try #require(catalog.info(named: "Example"))
        #expect(strain.breeder == nil)
        #expect(strain.effects == ["Happy"])
        #expect(strain.sourceIDs.isEmpty)
    }
}

@Suite struct StrainCatalogEdgeTests {
    let catalog = StrainCatalog(
        curated: Data(#"{"strains":[{"n":"GMO","a":["Garlic Cookies"],"t":"Hybrid"},{"n":"Zkittlez","a":["Zki"],"t":"Indica"}]}"#.utf8),
        community: Data(#"{"strains":[{"n":"Indica","t":"Indica"},{"n":"Kush","t":"Indica"}]}"#.utf8)
    )

    @Test func genericWordsDoNotMatch() {
        #expect(catalog.match(productName: "COG Selection Indica") == nil)
        #expect(catalog.match(productName: "Indica")?.match == .exact)
    }

    @Test func crossesInNames() {
        #expect(catalog.crossParents(in: "Bio Gmo x Zki") == ["GMO", "Zkittlez"])
        #expect(catalog.crossParents(in: "Cali Mix").isEmpty)
    }
}
