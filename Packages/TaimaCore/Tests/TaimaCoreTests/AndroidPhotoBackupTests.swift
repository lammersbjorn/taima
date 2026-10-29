import Foundation
import Testing
@testable import TaimaCore
#if canImport(ImageIO)
import ImageIO
#endif

/// Apple-written synthetic interoperability inputs. Generated only by an explicit local run.
struct AndroidPhotoBackupTests {
    @Test func applePhotoArchiveAndOptionalAndroidReturn() throws {
        guard let folder = ProcessInfo.processInfo.environment["TAIMA_ANDROID_FIXTURES_DIR"] else { return }
        let root = URL(fileURLWithPath: folder, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        // A synthetic 1x1 PNG. No user photos or application state.
        let png = try #require(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="))
        #if canImport(ImageIO)
        let source = try #require(CGImageSourceCreateWithData(png as CFData, nil))
        #expect(CGImageSourceCreateImageAtIndex(source, 0, nil) != nil)
        #endif
        if let returned = ProcessInfo.processInfo.environment["TAIMA_ANDROID_RETURN_ARCHIVE"] {
            let result = try BackupArchive.read(from: URL(fileURLWithPath: returned), passphrase: "synthetic-photo-only") { _, bytes in
                #expect(bytes == png)
                #if canImport(ImageIO)
                #expect(CGImageSourceCreateWithData(bytes as CFData, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) } != nil)
                #endif
            }
            let expected = try AndroidAPI.decode(BackupArchive.Manifest.self, JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("photo-manifest.json"))))
            #expect(result.bags == expected.bags && result.wishlist == expected.wishlist && result.producerKeys == expected.producerKeys)
        } else {
        let photo = "00000000-0000-4000-8000-000000000093.heic"
        var edible = Bag(id: UUID(uuidString: "00000000-0000-4000-8000-000000000091")!, name: "Synthetic pieces", grams: 4, photoName: photo, stock: .full, form: .edible)
        edible.thcMilligrams = 7.5
        edible.use(0.5, details: UsageEntry(grams: 0.5, method: .edible, note: "Synthetic session"))
        edible.noteLog = [TimedNote(text: "Synthetic photo note", photoName: photo)]
        let rosin = Bag(id: UUID(uuidString: "00000000-0000-4000-8000-000000000092")!, name: "Synthetic rosin", grams: 1, stock: .full, form: .rosin)
        let manifest = BackupArchive.Manifest(bags: [edible, rosin], wishlist: [], producerKeys: [:], exportedAt: .now)
        try AndroidAPI.encoder().encode(manifest).write(to: root.appendingPathComponent("photo-manifest.json"))
        try png.write(to: root.appendingPathComponent("synthetic-photo.png"))
        try BackupArchive.write(to: root.appendingPathComponent("apple-photo.taimabackup"), manifest: manifest, photoNames: [photo], photo: { _ in png }, passphrase: "synthetic-photo-only")
        }
    }
}
