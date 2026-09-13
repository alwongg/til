import Foundation

// I decode server dates at the boundary so the rest of the app can use Date safely.
struct Article: Decodable, Sendable {
    let id: UUID
    let title: String
    let publishedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case title = "headline"
        case publishedAt = "published_at"
    }
}

extension JSONDecoder {
    static var api: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)

            // ISO8601DateFormatter is intentionally kept here: the transport owns this format.
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            guard let date = formatter.date(from: rawValue) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Expected ISO-8601 date, received \(rawValue)"
                )
            }
            return date
        }
        return decoder
    }
}
