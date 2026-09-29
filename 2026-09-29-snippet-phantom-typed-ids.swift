import Foundation

// I use phantom types to make identifier mix-ups impossible at compile time.
struct ID<Kind>: Hashable, Codable, CustomStringConvertible {
    let rawValue: UUID

    init() { rawValue = UUID() }
    init(_ rawValue: UUID) { self.rawValue = rawValue }

    var description: String { rawValue.uuidString }
}

enum UserKind {}
enum OrderKind {}

typealias UserID = ID<UserKind>
typealias OrderID = ID<OrderKind>

struct User: Identifiable, Codable {
    let id: UserID
    let name: String
}

struct Order: Identifiable, Codable {
    let id: OrderID
    let ownerID: UserID // The relationship says exactly which ID belongs here.
}

func loadUser(_ id: UserID) async throws -> User {
    // Keeping the boundary typed prevents an OrderID reaching this API by accident.
    User(id: id, name: "Alex")
}

@main
struct Demo {
    static func main() async throws {
        let user = try await loadUser(UserID())
        print(user.name)
    }
}
