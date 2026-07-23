import Foundation

// I use a phantom marker so IDs from different domains cannot mix by accident.
protocol IDDomain {}

enum UserDomain: IDDomain {}
enum OrderDomain: IDDomain {}

struct ID<Domain: IDDomain>: Hashable, Codable, Sendable,
    CustomStringConvertible {
    let rawValue: UUID

    init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }

    var description: String { rawValue.uuidString }
}

typealias UserID = ID<UserDomain>
typealias OrderID = ID<OrderDomain>

struct Order: Sendable {
    let id: OrderID
    let ownerID: UserID
}

func loadOrder(_ id: OrderID) async throws -> Order {
    // The compiler prevents passing a UserID to this boundary.
    Order(id: id, ownerID: UserID())
}

@main
struct Demo {
    static func main() async throws {
        let order = try await loadOrder(OrderID())
        print("Loaded order \(order.id) for \(order.ownerID)")
    }
}
