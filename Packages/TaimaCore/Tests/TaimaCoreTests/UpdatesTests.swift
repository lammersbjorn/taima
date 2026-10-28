import Foundation
import Testing
@testable import TaimaCore

@Suite struct UpdatesTests {
    @Test func feedFindsNewerVersion() throws {
        let json = #"{"name":"Taima","apps":[{"bundleIdentifier":"com.bjorn.taima","versions":[{"version":"1.5","buildVersion":"7"},{"version":"1.6","buildVersion":"8","localizedDescription":"New"}]},{"bundleIdentifier":"other","versions":[]}]}"#
        let feed = try SourceFeed.decode(Data(json.utf8))
        #expect(feed.update(for: "com.bjorn.taima", currentBuild: 7)?.version == "1.6")
        #expect(feed.update(for: "com.bjorn.taima", currentBuild: 8) == nil)
        #expect(feed.update(for: "missing", currentBuild: 1) == nil)
    }

    @Test func manifestVerifiesFiles() throws {
        let data = Data(#"{"strains":[]}"#.utf8)
        let file = CatalogManifest.File(name: "strains.json", sha256: CatalogManifest.sha256(data), size: data.count)
        let manifest = CatalogManifest(version: 3, files: [file])
        #expect(manifest.isWellFormed)
        #expect(manifest.verify(data, for: file))
        #expect(!manifest.verify(Data("tampered".utf8), for: file))
        #expect(!CatalogManifest(version: 1, files: [.init(name: "../x.json", sha256: "", size: 0)]).isWellFormed)
    }

    @Test func profileExpiry() {
        let plist = #"<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>ExpirationDate</key><date>2026-11-04T10:00:00Z</date></dict></plist>"#
        let data = Data("binary-prefix".utf8) + Data(plist.utf8) + Data("signature".utf8)
        #expect(EmbeddedProfile.expirationDate(in: data) == ISO8601DateFormatter().date(from: "2026-11-04T10:00:00Z"))
        #expect(EmbeddedProfile.expirationDate(in: Data("nothing".utf8)) == nil)
    }

    @Test func refreshPolicy() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(RefreshPolicy.notice(expiry: now.addingTimeInterval(86_400), now: now) == .expiresSoon(now.addingTimeInterval(86_400)))
        #expect(RefreshPolicy.notice(expiry: now.addingTimeInterval(-1), now: now) == .expired(now.addingTimeInterval(-1)))
        #expect(RefreshPolicy.notice(expiry: now.addingTimeInterval(5 * 86_400), now: now) == nil)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
        let expiry = calendar.date(from: DateComponents(year: 2027, month: 3, day: 10, hour: 15))!
        let reminder = RefreshPolicy.reminderDate(expiry: expiry, now: now, calendar: calendar)!
        #expect(calendar.component(.day, from: reminder) == 9 && calendar.component(.hour, from: reminder) == 10)
    }
}
