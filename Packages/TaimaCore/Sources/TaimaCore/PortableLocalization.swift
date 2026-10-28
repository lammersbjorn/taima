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

// Evaluating SwiftPM's generated Bundle.module traps when Android has no
// Apple-style resource bundle. Portable UI strings are resource keys resolved
// by Android. Apple platforms retain their original string-catalog bundle.
extension Bundle {
    static var taimaLocalization: Bundle {
        #if canImport(Darwin)
        .module
        #else
        .main
        #endif
    }
}
