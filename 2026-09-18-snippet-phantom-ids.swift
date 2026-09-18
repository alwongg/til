// Swift Snippet: Phantom Types for Safer IDs
//
// I use phantom types when several identifiers share String as their storage
// but must never be passed to the wrong API boundary. The generic marker has
// no runtime cost; it makes accidental cross-wiring a compile-time error.

import Foundation

struct ID<Kind>: Hashable, Codable, Sendable, CustomStringConvertible {
    let rawValue: String

    init(_ rawValue: String) {
        precondition(!rawValue.isEmpty, "IDs must not be empty")
        self.rawValue = rawValue
    }

    var description: String { rawValue }
}

enum UserKind {}
enum OrderKind {}

typealias UserID = ID<UserKind>
typealias OrderID = ID<OrderKind>

struct OrderService {
    func fetch(orderID: OrderID) async throws -> String {
        "Order \(orderID)"
    }
}

func loadOrder(_ id: OrderID, using service: OrderService) async throws -> String {
    try await service.fetch(orderID: id)
}

// let userID = UserID("usr_123")
// try await loadOrder(userID, using: OrderService()) // Compile-time error.
