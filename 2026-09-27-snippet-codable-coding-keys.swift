// I use CodingKeys to keep Swift names idiomatic while accepting an API contract I do not control.
import Foundation

struct Release: Codable, Sendable {
    let id: UUID
    let buildNumber: Int
    let releaseNotes: String?
    let publishedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case buildNumber = "build_number"
        case releaseNotes = "release_notes"
        case publishedAt = "published_at"
    }
}

func decodeRelease(from data: Data) throws -> Release {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(Release.self, from: data)
}

func encodeRelease(_ release: Release) throws -> Data {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
    return try encoder.encode(release)
}

// I keep translation here, at the transport boundary, so the rest of the app
// can use buildNumber and publishedAt without leaking snake_case everywhere.
