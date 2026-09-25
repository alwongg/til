// Swift Snippet: Phantom Types for Safer IDs
//
// I use a phantom type when two IDs share the same raw representation but must
// never be interchangeable. The tag is compile-time-only: it costs nothing at runtime.

import Foundation

struct ID<Tag, RawValue: Hashable>: Hashable, Sendable where RawValue: Sendable {
    let rawValue: RawValue

    init(_ rawValue: RawValue) {
        self.rawValue = rawValue
    }
}

enum UserTag {}
enum OrderTag {}

typealias UserID = ID<UserTag, UUID>
typealias OrderID = ID<OrderTag, UUID>

struct Order: Sendable {
    let id: OrderID
    let ownerID: UserID
}

func loadOrder(id: OrderID) async throws -> Order {
    // Keeping the endpoint boundary typed prevents a user ID from reaching it.
    Order(id: id, ownerID: UserID(UUID()))
}

func example() async throws {
    let orderID = OrderID(UUID())
    let order = try await loadOrder(id: orderID)
    print(order.id.rawValue)

    // try await loadOrder(id: order.ownerID) // Compile-time error — exactly the point.
}
