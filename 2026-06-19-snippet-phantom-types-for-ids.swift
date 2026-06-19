import Foundation

// I use phantom types when multiple IDs arrive as the same raw type from an API.
// The compiler stops me from mixing them up, but the runtime representation stays cheap.
enum UserTag {}
enum OrderTag {}

struct ID<Tag>: Hashable, Codable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    let rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }

    var description: String { rawValue }
}

struct User: Codable, Sendable {
    let id: ID<UserTag>
    let name: String
}

struct Order: Codable, Sendable {
    let id: ID<OrderTag>
    let ownerID: ID<UserTag>
    let totalCents: Int
}

func canAccessOrder(userID: ID<UserTag>, order: Order) -> Bool {
    userID == order.ownerID
}

@main
enum Demo {
    static func main() {
        let user = User(id: ID("user_42"), name: "Alex")
        let order = Order(id: ID("order_7"), ownerID: user.id, totalCents: 2499)

        print(canAccessOrder(userID: user.id, order: order))
        print("User ID:", user.id)
        print("Order ID:", order.id)

        // This is the whole point: the next line would not compile.
        // print(canAccessOrder(userID: order.id, order: order))
    }
}
