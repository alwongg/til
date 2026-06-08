import Foundation

// I reach for strategy when the workflow is stable but one decision changes by feature flag or product tier.
// Exporting image payloads is a good example: the caller wants "compressed data", not JPEG rules everywhere.

protocol ImageEncodingStrategy {
    func encode(_ data: Data) -> Data
}

struct LosslessEncoding: ImageEncodingStrategy {
    func encode(_ data: Data) -> Data { data }
}

struct CappedEncoding: ImageEncodingStrategy {
    let maxBytes: Int

    func encode(_ data: Data) -> Data {
        data.count <= maxBytes ? data : data.prefix(maxBytes)
    }
}

struct AvatarExporter {
    private let strategy: ImageEncodingStrategy

    init(strategy: ImageEncodingStrategy) {
        self.strategy = strategy
    }

    func export(_ data: Data) -> Data {
        strategy.encode(data)
    }
}

let source = Data(repeating: 0xAB, count: 16)
let original = AvatarExporter(strategy: LosslessEncoding()).export(source)
let thumbnail = AvatarExporter(strategy: CappedEncoding(maxBytes: 6)).export(source)

print("original bytes: \(original.count)")
print("thumbnail bytes: \(thumbnail.count)")

// In production I usually hide strategy selection in composition code so feature modules depend on the protocol, not variants.
