// Swift Snippet: Decode API drift without leaking wire names through the app
//
// I keep server naming at the decoding boundary. The rest of my feature gets
// a small Swift-shaped model, so a backend rename has one obvious blast radius.

import Foundation

struct Profile: Decodable, Sendable {
    let id: UUID
    let displayName: String
    let joinedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id = "user_id"
        case displayName = "display_name"
        case joinedAt = "joined_at"
    }
}

struct ProfileDecoder {
    private let decoder: JSONDecoder

    init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func decode(_ data: Data) throws -> Profile {
        // This is the only place transport JSON is allowed to enter the feature.
        try decoder.decode(Profile.self, from: data)
    }
}

@main
struct Demo {
    static func main() throws {
        let json = #"{"user_id":"C3EE3A2E-4C40-4DFD-9E82-2A747B3BD6D2","display_name":"Mochi","joined_at":"2026-07-29T12:00:00Z"}"#
        let profile = try ProfileDecoder().decode(Data(json.utf8))
        print(profile.displayName)
    }
}
