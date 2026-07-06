import Foundation

// I use phantom types when two UUIDs have the same shape but different meaning.
// The compiler becomes the boundary instead of a review checklist.
struct ID<Tag>: Hashable, Codable, Sendable, CustomStringConvertible {
    let rawValue: UUID

    init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }

    var description: String { rawValue.uuidString }
}

enum UserTag {}
enum OrderTag {}

typealias UserID = ID<UserTag>
typealias OrderID = ID<OrderTag>

struct User: Sendable {
    let id: UserID
    let name: String
}

struct Order: Sendable {
    let id: OrderID
    let userID: UserID
}

func loadUser(id: UserID) -> User {
    User(id: id, name: "Alex")
}

func makeOrder(for userID: UserID) -> Order {
    Order(id: OrderID(), userID: userID)
}

// loadUser(id: OrderID())
// The wrong ID type now fails at compile time instead of leaking into production.
