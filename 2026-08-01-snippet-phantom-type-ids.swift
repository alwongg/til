// Phantom types prevent accidental mixing of IDs that are both strings.
// I use this at module boundaries so a compiler error replaces a production data bug.

struct ID<Tag>: Hashable, Codable, Sendable {
    let rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

enum UserTag {}
enum OrderTag {}

typealias UserID = ID<UserTag>
typealias OrderID = ID<OrderTag>

func loadOrder(_ id: OrderID) async throws -> String {
    "Order \(id.rawValue)"
}

@main
struct Demo {
    static func main() async throws {
        let order = OrderID("ord_42")
        print(try await loadOrder(order))

        // `loadOrder(UserID("usr_42"))` does not compile — exactly the guard I want.
    }
}
