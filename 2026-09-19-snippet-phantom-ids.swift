// Swift Snippet: Phantom Types for Safer IDs
//
// I use phantom types when two IDs have the same storage but must never be
// interchangeable. The generic marker exists only at compile time, so this
// adds safety without changing the runtime representation.

import Foundation

struct ID<Tag>: Hashable, Codable, Sendable {
    let rawValue: UUID

    init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

enum UserTag {}
enum OrderTag {}

typealias UserID = ID<UserTag>
typealias OrderID = ID<OrderTag>

struct User: Identifiable, Sendable {
    let id: UserID
    let name: String
}

func loadUser(_ id: UserID) async throws -> User {
    // The signature prevents an OrderID reaching this boundary by accident.
    User(id: id, name: "Alex")
}

func example() async throws {
    let userID = UserID()
    let orderID = OrderID()

    _ = try await loadUser(userID)
    _ = orderID // Keep the contrasting type visible in this compiling example.
    // _ = try await loadUser(orderID) // Compile-time error: exactly the point.
}

// I reach for this at module boundaries: routing, persistence, and API clients.
// A UUID wrapper is cheap; a production ID mix-up is not.
