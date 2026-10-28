import Foundation

/// Cross-compiled tests cannot follow a source path on the build host.
enum TestResources {
    static var root: URL {
        if let path = ProcessInfo.processInfo.environment["TAIMA_REPO_ROOT"] {
            return URL(fileURLWithPath: path)
        }
        return URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../..", isDirectory: true).standardized
    }
    static var app: URL { root.appendingPathComponent("App/Taima/Resources") }
    static var contracts: URL { root.appendingPathComponent("contracts/golden") }
}
