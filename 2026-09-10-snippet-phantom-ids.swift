import Foundation

// I make identifiers distinct at compile time, even though every ID is a UUID at runtime.
enum UserTag {}
enum OrderTag {}

struct ID<Tag>: RawRepresentable, Hashable, Codable, Sendable {
    let rawValue: UUID

    init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

typealias UserID = ID<UserTag>
typealias OrderID = ID<OrderTag>

struct Order: Sendable {
    let id: OrderID
    let ownerID: UserID
}

func loadOrder(_ id: OrderID, for user: UserID) -> Order {
    // The compiler prevents accidentally passing a user ID as an order ID.
    Order(id: id, ownerID: user)
}

func example() {
    let user = UserID()
    let order = OrderID()
    _ = loadOrder(order, for: user)
}
