// Swift Snippet: Decode API drift without leaking it into the app
//
// I keep server naming conventions at the Codable boundary. The rest of my
// feature works with Swift names, so a backend rename has one small blast radius.

import Foundation

struct Member: Codable, Sendable {
    let id: UUID
    let displayName: String
    let isPro: Bool
    let joinedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case isPro = "is_pro"
        case joinedAt = "joined_at"
    }
}

enum MemberDecoder {
    static func decode(_ data: Data) throws -> Member {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Member.self, from: data)
    }
}

// My ViewModel only sees member.displayName and member.joinedAt.
// It never needs to know the API prefers snake_case.
