/*
Slot 3 — Swift Snippet
Topic: Phantom types for IDs

I like phantom-typed IDs when two models both use UUID but I still want the compiler to stop me from mixing them up.
The generic wrapper carries a marker type at compile time, so `ID<User>` and `ID<Order>` serialize the same way while staying incompatible in code.
That gives me cheap safety at API and persistence boundaries without building heavyweight wrappers for every model.
*/

import Foundation

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

struct User: Codable, Sendable {
    let id: UserID
    let name: String
}

struct Order: Codable, Sendable {
    let id: OrderID
    let totalCents: Int
    let ownerID: UserID
}

@main
struct Demo {
    static func main() throws {
        let user = User(id: UserID(), name: "Alex")
        let order = Order(id: OrderID(), totalCents: 4200, ownerID: user.id)

        let encoded = try JSONEncoder().encode(order)
        let decoded = try JSONDecoder().decode(Order.self, from: encoded)

        print(user.id)
        print(decoded.ownerID)

        // This is the win: the compiler rejects accidental swaps.
        // let broken = Order(id: user.id, totalCents: 4200, ownerID: user.id)
    }
}
