import Foundation

struct ID<Tag>: Hashable, Sendable, CustomStringConvertible {
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
    let total: Decimal
}

let user = User(id: UserID(), name: "Alex")
let order = Order(id: OrderID(), userID: user.id, total: 42)

print("user=\(user.id)")
print("order belongs to user=\(order.userID)")
print(order.total)

// I use phantom types when multiple IDs share the same storage type.
// The payoff is compile-time safety: UserID and OrderID look identical at runtime,
// but Swift refuses to let me mix them up in feature code or networking glue.
// It is a small abstraction that prevents the kind of bug that survives reviews
// because every identifier is "just a UUID" until one gets passed to the wrong API.
