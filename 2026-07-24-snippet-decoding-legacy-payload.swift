import Foundation

// I keep wire-format compromises at the boundary so the rest of the feature
// can use names that match the product language.
struct Profile: Decodable, Sendable {
    let id: UUID
    let displayName: String
    let marketingOptIn: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "full_name"
        case marketingOptIn = "is_marketing_enabled"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        displayName = try values.decodeIfPresent(String.self, forKey: .displayName) ?? "Anonymous"
        marketingOptIn = try values.decodeIfPresent(Bool.self, forKey: .marketingOptIn) ?? false
    }
}

@main
struct Demo {
    static func main() throws {
        let json = "{\"id\":\"D420AAF3-0D21-42E8-B5F7-88F1D8C6A70B\",\"full_name\":\"Alex\"}"
        let profile = try JSONDecoder().decode(Profile.self, from: Data(json.utf8))
        print("\(profile.displayName): marketing = \(profile.marketingOptIn)")
    }
}
