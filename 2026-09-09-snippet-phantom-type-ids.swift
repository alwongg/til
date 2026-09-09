import Foundation

// # Swift Snippet: Phantom types prevent ID mix-ups
//
// I treat UUIDs as transport details, not domain types. A raw UUID lets me
// accidentally pass a Post ID to a User endpoint; this tiny generic wrapper
// makes that mistake fail at compile time without adding runtime cost.

enum UserTag {}
enum PostTag {}

struct ID<Tag>: Hashable, Codable, Sendable, CustomStringConvertible {
    let rawValue: UUID

    init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }

    var description: String { rawValue.uuidString }
}

typealias UserID = ID<UserTag>
typealias PostID = ID<PostTag>

struct User: Sendable {
    let id: UserID
    let name: String
}

func loadUser(id: UserID) async throws -> User {
    // The endpoint accepts only UserID, so loadUser(id: postID) cannot compile.
    User(id: id, name: "Mochi's human")
}

@main
enum Demo {
    static func main() async {
        let userID = UserID()
        let postID = PostID()
        _ = postID // Different domains can share the same UUID representation safely.

        let user = try? await loadUser(id: userID)
        print(user?.name ?? "Unavailable")
    }
}

// I add phantom types at API boundaries first: route parameters, repositories,
// and analytics events. That gives me compiler-enforced correctness while the
// rest of a feature can migrate incrementally.
