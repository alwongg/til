import Foundation

/*
I use phantom types when two identifiers share the same storage type but mean different things.
UUID is cheap to standardize on, but I never want UserID and OrderID to be interchangeable by accident.
*/

enum UserTag {}
enum OrderTag {}

struct ID<Tag>: Hashable, Codable, Sendable, CustomStringConvertible {
    let rawValue: UUID

    init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }

    var description: String { rawValue.uuidString }
}

struct User: Sendable {
    let id: ID<UserTag>
    let name: String
}

struct Order: Sendable {
    let id: ID<OrderTag>
    let totalCents: Int
}

func loadUser(id: ID<UserTag>) -> User {
    User(id: id, name: "Alex")
}

func attach(orderID: ID<OrderTag>, to userID: ID<UserTag>) -> String {
    "Order \(orderID) belongs to user \(userID)"
}

enum Example {
    static func compileTimeSafety() {
        let userID = ID<UserTag>()
        let orderID = ID<OrderTag>()

        _ = loadUser(id: userID)
        _ = attach(orderID: orderID, to: userID)

        // _ = loadUser(id: orderID) // Uncomment to watch the compiler reject the mix-up.
    }
}
