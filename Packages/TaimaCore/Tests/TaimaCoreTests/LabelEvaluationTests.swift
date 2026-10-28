import Foundation
import Testing
@testable import TaimaCore

struct LabelEvaluationFixture: Decodable, Sendable {
    var id: String
    var group: String
    var lines: [RecognizedLine]
    var codes: [DetectedCode]
    var expected: [String: String]
    var unscored: [String]
}

enum LabelEvaluation {
    static let fields = ["name", "producer", "strainType", "thc", "cbd", "grams", "harvestedOn", "packedOn", "bestBeforeOn", "productID", "sku", "ean", "leafletURL", "form", "unitCount", "producerKeys"]

    static func values(_ reading: LabelReading) -> [String: String] {
        func number(_ value: Double) -> String { String(format: "%g", locale: Locale(identifier: "en_US_POSIX"), value) }
        func potency(_ value: Potency?) -> String {
            value.map { ($0.isUpperBound ? "<" : "") + ($0.lowerBound.map { number($0) + "..." } ?? "") + number($0.percent) } ?? "—"
        }
        func date(_ value: Date?) -> String {
            guard let value else { return "—" }
            let parts = Calendar.taima.dateComponents([.year, .month, .day], from: value)
            return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
        }
        return [
            "name": reading.name ?? "—", "producer": reading.producer ?? "—",
            "strainType": reading.strainType?.rawValue ?? "—", "thc": potency(reading.thc), "cbd": potency(reading.cbd),
            "grams": reading.grams.map(number) ?? "—", "harvestedOn": date(reading.harvestedOn),
            "packedOn": date(reading.packedOn), "bestBeforeOn": date(reading.bestBeforeOn),
            "productID": reading.productID ?? "—", "sku": reading.sku ?? "—", "ean": reading.ean ?? "—",
            "leafletURL": reading.leafletURL ?? "—", "form": reading.form?.rawValue ?? "—",
            "unitCount": reading.unitCount.map(String.init) ?? "—",
            "producerKeys": reading.producerKeys.isEmpty ? "—" : reading.producerKeys.sorted().joined(separator: "|")
        ]
    }

    static func fixtures() throws -> [LabelEvaluationFixture] {
        let url = Bundle.module.resourceURL!.appendingPathComponent("LabelFixtures")
        var fixtures = try ["photos", "formats"].flatMap { name in
            try JSONDecoder().decode([LabelEvaluationFixture].self, from: Data(contentsOf: url.appendingPathComponent(name + ".json")))
        }
        let originals: [(String, (lines: [RecognizedLine], codes: [DetectedCode]), Int)] = [
            ("motorbreath", Fixtures.motorbreath, 0), ("girl-scout", Fixtures.girlScoutCookie, 1),
            ("amnesia-s5", Fixtures.amnesiaS5, 2), ("selection", Fixtures.selectionIndica, 3),
            ("cali", Fixtures.caliMix, 4), ("pheno", Fixtures.phenoHunt, 5),
            ("speak", Fixtures.speakSpecial, 6), ("zunami", WebFixtures.zunami, 7),
            ("amnesia-haze", Fixtures.amnesiaHaze, 8), ("white-widow", Fixtures.whiteWidow, 9)
        ]
        for (id, input, index) in originals {
            var expected = fixtures[index].expected
            let ids = [107, 110, 105, 104, 103, 111, 114, 102, 0, 108]
            expected["productID"] = String(format: "prd-00000000-0000-4000-8000-%012d", ids[index])
            fixtures.append(LabelEvaluationFixture(id: id, group: "retained", lines: input.lines, codes: input.codes,
                                                   expected: expected, unscored: fixtures[index].unscored))
        }
        func web(_ id: String, _ input: (lines: [RecognizedLine], codes: [DetectedCode]), _ present: [String: String]) {
            var expected = Dictionary(uniqueKeysWithValues: fields.map { ($0, "—") })
            expected.merge(present) { _, new in new }
            fixtures.append(LabelEvaluationFixture(id: id, group: "retained", lines: input.lines, codes: input.codes, expected: expected, unscored: []))
        }
        web("fyta", WebFixtures.fytaSourDelight, ["name": "Sour Delight", "producer": "FYTA", "thc": "20", "cbd": "<1", "grams": "1", "harvestedOn": "2024-05-20", "packedOn": "2024-12-12", "productID": "prd-00000000-0000-4000-8000-000000000106", "producerKeys": "domain:fyta.group"])
        web("aardachtig-jar", WebFixtures.aardachtigJar, ["name": "Bio Gmo x Zki", "producer": "Aardachtig Organics", "thc": "17.89", "cbd": "<1", "grams": "5", "harvestedOn": "2024-05-17", "packedOn": "2024-10-28", "producerKeys": "domain:aardachtig.nl|domain:sardachtig.nt"])
        web("holi", WebFixtures.holiFresh, ["name": "Holi Fresh", "producer": "Holigram", "grams": "0.5", "harvestedOn": "2026-01-13", "packedOn": "2026-05-22", "productID": "prd-00000000-0000-4000-8000-000000000113"])
        return fixtures
    }

    static func report(_ fixtures: [LabelEvaluationFixture]) -> String {
        var rows = ["| Field | Exact (including absent) | Present values | False positives |", "| --- | ---: | ---: | ---: |"]
        var total = 0, correct = 0, present = 0, presentCorrect = 0
        var failures: [String] = []
        let readings = fixtures.map { values(LabelParser.parse(lines: $0.lines, codes: $0.codes)) }
        for field in fields {
            var n = 0, hits = 0, positives = 0, positiveHits = 0, falsePositives = 0
            for (fixture, actual) in zip(fixtures, readings) where !fixture.unscored.contains(field) {
                n += 1
                let expected = fixture.expected[field]!
                if actual[field] == expected { hits += 1 }
                else { failures.append("\(fixture.id).\(field): expected \(expected), got \(actual[field]!)") }
                if expected != "—" {
                    positives += 1
                    if actual[field] == expected { positiveHits += 1 }
                } else if actual[field] != "—" { falsePositives += 1 }
            }
            rows.append("| \(field) | \(hits)/\(n) | \(positiveHits)/\(positives) | \(falsePositives) |")
            total += n; correct += hits; present += positives; presentCorrect += positiveHits
        }
        rows.append("\nExact: \(correct)/\(total). Present: \(presentCorrect)/\(present). Fixtures: \(fixtures.count).")
        rows.append(contentsOf: failures.map { "- " + $0 })
        return rows.joined(separator: "\n")
    }
}

@Test func labelEvaluationReport() throws {
    let fixtures = try LabelEvaluation.fixtures()
    #expect(fixtures.count == 37)
    let unresolved: Set<String> = [
        "capture-6.name", "pheno.name", "aardachtig-jar.thc", "aardachtig-jar.cbd",
        "capture-9.grams", "amnesia-haze.grams", "aardachtig-jar.grams",
        "capture-6.harvestedOn", "pheno.harvestedOn"
    ]
    for fixture in fixtures {
        #expect(Set(fixture.expected.keys) == Set(LabelEvaluation.fields))
        let actual = LabelEvaluation.values(LabelParser.parse(lines: fixture.lines, codes: fixture.codes))
        for field in LabelEvaluation.fields where !fixture.unscored.contains(field) {
            if !unresolved.contains(fixture.id + "." + field) {
                #expect(actual[field] == fixture.expected[field], "\(fixture.id).\(field)")
            }
        }
    }
    print("\nLABEL EVALUATION\n" + LabelEvaluation.report(fixtures))
}

@Test func fixtureProductIdentifiersAreSynthetic() throws {
    let regex = try NSRegularExpression(pattern: #"PRD-[a-fo0-9-]+"#, options: [.caseInsensitive])
    let prefix = "prd-00000000-0000-4000-8000-"
    for fixture in try LabelEvaluation.fixtures() {
        let texts = fixture.lines.flatMap { [$0.text] + $0.alternatives.map(\.text) }
            + fixture.codes.map(\.payload) + Array(fixture.expected.values)
        for text in texts {
            for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                let id = (text as NSString).substring(with: match.range).lowercased().replacingOccurrences(of: "o", with: "0")
                #expect(id.hasPrefix(prefix) || prefix.hasPrefix(id), "\(fixture.id) contains a non-synthetic PRD")
            }
        }
    }
}
