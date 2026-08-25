// Swift Snippet: Phantom Types for Safer IDs
//
// I use phantom types when two String IDs have the same representation but
// must never be accidentally passed to the wrong endpoint. The marker types
// exist only at compile time, so this keeps the runtime payload unchanged.

import Foundation

struct UserIDTag {}
struct OrderIDTag {}

struct ID<Tag>: Hashable, Codable, Sendable, CustomStringConvertible {
    let rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    var description: String { rawValue }
}

typealias UserID = ID<UserIDTag>
typealias OrderID = ID<OrderIDTag>

struct OrdersClient {
    func load(order id: OrderID) async throws -> String {
        // The URL still receives a string, but the API boundary demands OrderID.
        "Loaded order \(id)"
    }
}

func loadCurrentOrder(client: OrdersClient) async throws -> String {
    let orderID = OrderID("ord_42")
    return try await client.load(order: orderID)
}

// client.load(order: UserID("usr_42")) // Compile-time error: wrong ID domain.
