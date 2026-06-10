import Foundation

// I use custom CodingKeys when I want my Swift model to stay readable even when the API shape is noisy.
struct AccountSnapshot: Codable {
    let userID: Int
    let displayName: String
    let isProMember: Bool
    let lastUpdatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case displayName = "display_name"
        case isProMember = "pro_member"
        case lastUpdatedAt = "last_updated_at"
    }
}

@main
struct Demo {
    static func main() throws {
        let json = """
        {
          "user_id": 42,
          "display_name": "Alex Wong",
          "pro_member": true,
          "last_updated_at": "2026-06-10T16:55:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(AccountSnapshot.self, from: json)
        precondition(snapshot.displayName == "Alex Wong")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let encoded = try encoder.encode(snapshot)

        print(snapshot.userID, snapshot.isProMember)
        print(String(decoding: encoded, as: UTF8.self))
    }
}
