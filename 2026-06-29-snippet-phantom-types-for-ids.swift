// Swift Snippet — Phantom types for IDs
// I use phantom types when several IDs share the same raw shape.
// The compiler stops me from accidentally passing an OrderID where a UserID is required.

import Foundation

struct Tagged<Tag, RawValue: Hashable & Codable & Sendable>: Hashable, Codable, Sendable {
    let rawValue: RawValue

    init(_ rawValue: RawValue) {
        self.rawValue = rawValue
    }
}

enum UserTag: Sendable {}
enum OrderTag: Sendable {}

typealias UserID = Tagged<UserTag, UUID>
typealias OrderID = Tagged<OrderTag, UUID>

struct User: Codable, Sendable {
    let id: UserID
    let name: String
}

struct Order: Codable, Sendable {
    let id: OrderID
    let userID: UserID
    let totalCents: Int
}

func loadUser(id: UserID) -> String {
    "Loading user \(id.rawValue.uuidString)"
}

@main
enum Demo {
    static func main() {
        let userID = UserID(UUID())
        let order = Order(id: OrderID(UUID()), userID: userID, totalCents: 4200)

        print(loadUser(id: order.userID))
        // print(loadUser(id: order.id)) // Compile-time error: OrderID is not UserID.
    }
}
