import Foundation

// I keep wire-format compromises at the decoding boundary so the rest of the app
// can use names that match the domain instead of an API's historical vocabulary.
struct AccountSummary: Codable, Sendable {
    let accountID: UUID
    let displayName: String
    let isPremium: Bool
    let lastSyncedAt: Date?

    enum CodingKeys: String, CodingKey {
        case accountID = "account_id"
        case displayName = "display_name"
        case isPremium = "premium_member"
        case lastSyncedAt = "last_synced_at"
    }
}

extension JSONDecoder {
    static var api: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension JSONEncoder {
    static var api: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}

func decodeAccountSummary(from data: Data) throws -> AccountSummary {
    // I decode once at the boundary; views and use cases never see snake_case keys.
    try JSONDecoder.api.decode(AccountSummary.self, from: data)
}
