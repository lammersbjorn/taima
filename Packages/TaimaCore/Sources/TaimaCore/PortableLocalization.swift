import Foundation

#if !canImport(Darwin)
// Foundation on Android and Linux doesn't offer `String(localized:bundle:)`
// for literals or read string catalogs. Core text falls back to its English
// source there; the Android app translates on its side.
extension String {
    init(localized key: String, bundle: Bundle) {
        self = key
    }
}
#endif
