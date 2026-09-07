import Foundation

struct RemoteProfile: Codable, Sendable {
    let id: UUID
    let displayName: String
    let marketingOptIn: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case marketingOptIn = "marketing_opt_in"
    }

    init(id: UUID, displayName: String, marketingOptIn: Bool) {
        self.id = id
        self.displayName = displayName
        self.marketingOptIn = marketingOptIn
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)

        // I default old payloads to false so a missing consent field never opts a user in.
        marketingOptIn = try container.decodeIfPresent(Bool.self, forKey: .marketingOptIn) ?? false
    }
}

func encodedProfile(_ profile: RemoteProfile) throws -> Data {
    // I keep wire-name translation here, at the boundary, not scattered through views.
    try JSONEncoder().encode(profile)
}
