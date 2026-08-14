import Foundation

// I use a phantom generic to make IDs carry their domain at compile time.
// Both values remain a lightweight UUID at runtime.
struct ID<Tag>: RawRepresentable, Hashable, Codable, Sendable {
    let rawValue: UUID

    init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
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
    let ownerID: UserID
}

func loadOrders(for userID: UserID, from orders: [Order]) -> [Order] {
    // A bare UUID would let me accidentally pass an order ID here.
    // This comparison is only possible with the correct domain ID.
    orders.filter { $0.ownerID == userID }
}

func makePreviewData() -> (User, [Order]) {
    let user = User(id: UserID(), name: "Mochi")
    let orders = [Order(id: OrderID(), ownerID: user.id)]
    return (user, orders)
}
