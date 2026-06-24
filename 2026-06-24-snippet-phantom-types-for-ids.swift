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

struct User: Sendable {
    let id: UserID
    let name: String
}

struct Order: Sendable {
    let id: OrderID
    let ownerID: UserID
    let totalCents: Int
}

func attach(orderID: OrderID, to userID: UserID) -> String {
    "Attached order \(orderID) to user \(userID)"
}

@main
enum Demo {
    static func main() {
        let user = User(id: UserID(), name: "Alex")
        let order = Order(id: OrderID(), ownerID: user.id, totalCents: 4_299)

        print(attach(orderID: order.id, to: user.id))
        // attach(orderID: user.id, to: order.id) // compile-time error instead of a prod bug
    }
}
