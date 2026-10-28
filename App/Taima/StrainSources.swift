import Foundation

/// Where curated strain facts come from: the registry in
/// docs/research/strain-sources.md, shipped with the library.
nonisolated struct StrainSources: Sendable {
    struct Source: Identifiable, Sendable {
        let id: String
        let record: String
        let url: String?

        var host: String? {
            url.flatMap(URL.init(string:))?.host()?.replacingOccurrences(of: "www.", with: "")
        }

        /// "AK-020 · amsterdamgenetics.com".
        var title: String { [record, host].compactMap { $0 }.joined(separator: " · ") }
    }

    private struct File: Decodable {
        struct Entry: Decodable { let record: String; let url: String? }
        let sources: [String: Entry]
    }

    private var byID: [String: Source] = [:]

    init(data: Data?) {
        guard let data, let file = try? JSONDecoder().decode(File.self, from: data) else { return }
        for (id, entry) in file.sources {
            byID[id] = Source(id: id, record: entry.record, url: entry.url)
        }
    }

    func resolve(_ ids: [String]) -> [Source] { ids.compactMap { byID[$0] } }
}
