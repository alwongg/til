// I use phantom types when two identifier strings look alike but must never be interchangeable.
// The empty marker types disappear at runtime while the compiler protects the boundary.

struct ID<Kind>: Hashable, Sendable, Codable, CustomStringConvertible {
    let rawValue: String

    init(_ rawValue: String) {
        precondition(!rawValue.isEmpty, "An ID must not be empty")
        self.rawValue = rawValue
    }

    var description: String { rawValue }
}

enum UserKind {}
enum OrderKind {}

typealias UserID = ID<UserKind>
typealias OrderID = ID<OrderKind>

struct Order: Sendable {
    let id: OrderID
    let ownerID: UserID
}

func loadOrder(_ id: OrderID) async throws -> Order {
    // This boundary can no longer accidentally receive a UserID.
    Order(id: id, ownerID: UserID("user_42"))
}

func example() async throws {
    let orderID = OrderID("order_100")
    let order = try await loadOrder(orderID)
    print(order.ownerID)
}
