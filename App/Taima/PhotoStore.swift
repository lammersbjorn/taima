import ImageIO
import UIKit

/// Compressed photo files in Application Support. Re-rendering drops EXIF
/// metadata, including location, before anything is written.
nonisolated struct PhotoStore: Sendable {
    let directory: URL

    static let fullSize: CGFloat = 1600
    static let thumbnailSize: CGFloat = 360
    static let readingSize: CGFloat = 2400

    init(directory: URL) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func url(for name: String) -> URL { directory.appending(path: name) }

    func thumbnailURL(for name: String) -> URL {
        directory.appending(path: name.replacingOccurrences(of: ".heic", with: "-thumb.heic"))
    }

    /// Saves a full photo and a thumbnail and returns the photo's file name.
    func save(_ image: UIImage) throws -> String {
        let name = UUID().uuidString + ".heic"
        try write(data(for: image.resized(maxSide: Self.fullSize), quality: 0.55), to: url(for: name))
        try write(data(for: image.resized(maxSide: Self.thumbnailSize), quality: 0.6), to: thumbnailURL(for: name))
        return name
    }

    func save(data: Data, named name: String) throws {
        try write(data, to: url(for: name))
        if let image = UIImage(data: data) {
            try write(self.data(for: image.resized(maxSide: Self.thumbnailSize), quality: 0.6), to: thumbnailURL(for: name))
        }
    }

    /// Decodes and re-encodes a photo from elsewhere, dropping any metadata.
    func saveReencoded(data: Data, named name: String) throws {
        guard let image = UIImage(data: data) else { return }
        try write(self.data(for: image.resized(maxSide: Self.fullSize), quality: 0.55), to: url(for: name))
        try write(self.data(for: image.resized(maxSide: Self.thumbnailSize), quality: 0.6), to: thumbnailURL(for: name))
    }

    /// For backups: nil when the photo doesn't exist, an error when it
    /// exists but can't be read, so a backup never silently drops it.
    func dataForBackup(named name: String) throws -> Data? {
        let url = url(for: name)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    func data(named name: String) -> Data? {
        try? Data(contentsOf: url(for: name))
    }

    /// Removes every stored photo and thumbnail.
    func deleteAll() {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for file in files { try? FileManager.default.removeItem(at: file) }
    }

    func delete(_ name: String) {
        try? FileManager.default.removeItem(at: url(for: name))
        try? FileManager.default.removeItem(at: thumbnailURL(for: name))
    }

    private func data(for image: UIImage, quality: CGFloat) -> Data {
        image.heicData(quality: quality) ?? image.jpegData(compressionQuality: quality) ?? Data()
    }

    private func write(_ data: Data, to url: URL) throws {
        // Readable after the first unlock: automatic backups run as the app
        // goes to the background, often right as the iPhone locks.
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    /// The capture date recorded by the camera, if the file has one.
    static func captureDate(in data: Data) -> Date? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
              let text = exif[kCGImagePropertyExifDateTimeOriginal] as? String
        else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: text)
    }
}

nonisolated extension UIImage {
    /// Draws the image upright at no more than `maxSide` pixels.
    func resized(maxSide: CGFloat) -> UIImage {
        let pixelSize = CGSize(width: size.width * scale, height: size.height * scale)
        let factor = min(1, maxSide / max(pixelSize.width, pixelSize.height))
        let target = CGSize(width: (pixelSize.width * factor).rounded(), height: (pixelSize.height * factor).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }

    func heicData(quality: CGFloat) -> Data? {
        guard let cgImage else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.heic" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, cgImage, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
