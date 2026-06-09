import Foundation

// I use phantom types to stop the compiler from letting unrelated identifiers mix.
struct ID<Tag>: Hashable, Codable, CustomStringConvertible {
    let rawValue: UUID

    init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }

    var description: String { rawValue.uuidString }
}

enum UserTag {}
enum OrderTag {}

struct User {
    let id: ID<UserTag>
    let name: String
}

struct Order {
    let id: ID<OrderTag>
    let ownerID: ID<UserTag>
}

func loadUser(id: ID<UserTag>) -> User {
    User(id: id, name: "Alex")
}

@main
struct Demo {
    static func main() {
        let userID = ID<UserTag>()
        let orderID = ID<OrderTag>()
        let user = loadUser(id: userID)
        print(user.name, orderID)

        // loadUser(id: orderID) // This is the point: the wrong ID type never compiles.
    }
}
