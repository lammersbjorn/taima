import Foundation
import TaimaCore

/// The same realistic operation is used by generated and handwritten JNI.
/// An explicit result envelope keeps Swift errors out of the C ABI.
public func normalizeBagJSON(_ json: String) -> String {
    do {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var bag = try decoder.decode(Bag.self, from: Data(json.utf8))
        bag.name = bag.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bag.name.isEmpty,
              bag.grams.map({ $0.isFinite && $0 >= 0 }) ?? true,
              bag.remainingGrams.map({ $0.isFinite && $0 >= 0 && $0 <= (bag.grams ?? $0) }) ?? true,
              [bag.thc, bag.cbd].compactMap({ $0 }).allSatisfy({ $0.percent.isFinite && (0...100).contains($0.percent) })
        else { return #"{"error":"invalidRecord"}"# }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let record = String(decoding: try encoder.encode(bag), as: UTF8.self)
        return "{\"record\":" + record + "}"
    } catch {
        return #"{"error":"invalidJSON"}"#
    }
}

@_cdecl("taima_normalize")
public func taimaNormalize(_ bytes: UnsafePointer<UInt8>?, _ count: Int) -> UnsafeMutablePointer<CChar>? {
    guard let bytes, count >= 0 else { return nil }
    let result = normalizeBagJSON(String(decoding: UnsafeBufferPointer(start: bytes, count: count), as: UTF8.self))
    let utf8 = Array(result.utf8CString)
    let output = UnsafeMutablePointer<CChar>.allocate(capacity: utf8.count)
    output.initialize(from: utf8, count: utf8.count)
    return output
}

@_cdecl("taima_free")
public func taimaFree(_ pointer: UnsafeMutablePointer<CChar>?) { pointer?.deallocate() }

/// One JNI entry around many core calls estimates the boundary's contribution.
@_cdecl("taima_core_batch_ns")
public func taimaCoreBatch(_ bytes: UnsafePointer<UInt8>?, _ count: Int, _ iterations: Int) -> Double {
    guard let bytes, count >= 0, iterations > 0 else { return -1 }
    let input = String(decoding: UnsafeBufferPointer(start: bytes, count: count), as: UTF8.self)
    var checksum = 0
    let elapsed = ContinuousClock().measure {
        for _ in 0..<iterations { checksum &+= normalizeBagJSON(input).utf8.count }
    }
    guard checksum > 0 else { return -1 }
    let parts = elapsed.components
    return (Double(parts.seconds) * 1e9 + Double(parts.attoseconds) / 1e9) / Double(iterations)
}

@_cdecl("taima_call")
public func taimaCall(_ bytes: UnsafePointer<UInt8>?, _ count: Int) -> UnsafeMutablePointer<CChar>? {
    guard let bytes, count >= 0 else { return nil }
    let result = AndroidAPI.call(Data(bytes: bytes, count: count))
    let utf8 = Array(String(decoding: result, as: UTF8.self).utf8CString)
    let output = UnsafeMutablePointer<CChar>.allocate(capacity: utf8.count)
    output.initialize(from: utf8, count: utf8.count)
    return output
}
