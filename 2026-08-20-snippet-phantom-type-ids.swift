// Swift Snippet: Phantom Types for Safer IDs
//
// I use phantom types when several identifiers share the same raw representation.
// The compiler then prevents a UserID from accidentally reaching an Order endpoint.

import Foundation

struct ID<RawValue: Hashable, Tag>: Hashable, Sendable where RawValue: Sendable {
    let rawValue: RawValue

    init(_ rawValue: RawValue) {
        self.rawValue = rawValue
    }
}

enum UserIDTag: Sendable {}
enum OrderIDTag: Sendable {}

typealias UserID = ID<UUID, UserIDTag>
typealias OrderID = ID<UUID, OrderIDTag>

struct User: Sendable {
    let id: UserID
    let name: String
}

protocol UserLoading: Sendable {
    func loadUser(id: UserID) async throws -> User
}

struct UserAPI: UserLoading {
    func loadUser(id: UserID) async throws -> User {
        // The typed boundary keeps URL construction and decoding behind this API.
        User(id: id, name: "Alex")
    }
}

func showProfile(id: UserID, loader: some UserLoading) async throws -> User {
    try await loader.loadUser(id: id)
}

@main
struct Demo {
    static func main() async {
        let userID = UserID(UUID())
        let orderID = OrderID(UUID())
        _ = orderID

        // This compiles:
        _ = try? await showProfile(id: userID, loader: UserAPI())

        // This does not compile, which is the point:
        // _ = try? await showProfile(id: orderID, loader: UserAPI())
    }
}
