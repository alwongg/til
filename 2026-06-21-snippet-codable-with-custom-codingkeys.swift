import Foundation

/// Swift Snippet: Codable with custom CodingKeys
///
/// I use custom CodingKeys when the payload is mostly clean, but a few backend
/// fields don't deserve to leak into my Swift naming. That keeps the model
/// readable without forcing the whole decoder through a bespoke parsing path.

struct APIEnvelope<Payload: Decodable>: Decodable {
    let data: Payload
}

struct Episode: Decodable {
    let id: Int
    let title: String
    let isFeatured: Bool
    let publishedAt: Date
    let playbackURL: URL

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case isFeatured = "featured_flag"
        case publishedAt = "published_at"
        case playbackURL = "playback_url"
    }
}

@main
enum Demo {
    static func main() throws {
        let json = """
        {
          "data": {
            "id": 42,
            "title": "Swift Concurrency Notes",
            "featured_flag": true,
            "published_at": "2026-06-21T12:30:00Z",
            "playback_url": "https://example.com/episodes/42"
          }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let envelope = try decoder.decode(APIEnvelope<Episode>.self, from: json)

        // I assert the fields I care about most so contract drift fails loudly in tests.
        precondition(envelope.data.isFeatured)
        precondition(envelope.data.playbackURL.host == "example.com")
        precondition(Calendar(identifier: .gregorian).component(.year, from: envelope.data.publishedAt) == 2026)
    }
}
