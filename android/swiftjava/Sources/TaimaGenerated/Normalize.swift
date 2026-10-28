import TaimaBridge

/// Identical operation, generated JNI instead of the handwritten C adapter.
public func normalizeBagJSON(_ json: String) -> String {
    TaimaBridge.normalizeBagJSON(json)
}
