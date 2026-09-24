// Swift Snippet: Phantom Types for IDs
//
// I use phantom types when two raw IDs are both strings but must never be
// interchangeable. The compiler then catches an entire class of routing and
// persistence mistakes before they reach production.

import Foundation

struct ID<Kind>: Hashable, Codable, Sendable, CustomStringConvertible {
    let rawValue: String

    init(_ rawValue: String) {
        precondition(!rawValue.isEmpty, "IDs must not be empty")
        self.rawValue = rawValue
    }

    var description: String { rawValue }
}

enum User {}
enum Order {}

typealias UserID = ID<User>
typealias OrderID = ID<Order>

struct OrderDetailRoute: Hashable, Sendable {
    let userID: UserID
    let orderID: OrderID
}

func loadOrder(_ route: OrderDetailRoute) async throws {
    // The distinct types prevent accidentally sending userID as orderID.
    print("Loading order \(route.orderID) for user \(route.userID)")
}

@main
struct Demo {
    static func main() async throws {
        let route = OrderDetailRoute(userID: UserID("u_42"), orderID: OrderID("o_99"))
        try await loadOrder(route)
    }
}
