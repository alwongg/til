// Swift Snippet: prevent mixing domain IDs with phantom types
//
// I use a zero-cost tag to make `UserID` and `OrderID` distinct at compile time.
// Both are strings at the API boundary, but Swift refuses accidental cross-domain use.

import Foundation

struct ID<Tag>: Hashable, Sendable, Codable, CustomStringConvertible {
    let rawValue: String

    init(_ rawValue: String) {
        precondition(!rawValue.isEmpty, "IDs should not be empty")
        self.rawValue = rawValue
    }

    var description: String { rawValue }
}

enum UserTag {}
enum OrderTag {}

typealias UserID = ID<UserTag>
typealias OrderID = ID<OrderTag>

struct User: Sendable, Codable {
    let id: UserID
    let name: String
}

protocol UserLoading: Sendable {
    func loadUser(id: UserID) async throws -> User
}

// This cannot compile, which is the point:
// let orderID = OrderID("order_42")
// try await loader.loadUser(id: orderID)

func userPath(for id: UserID) -> URL {
    URL(string: "https://api.example.com/users/\(id.rawValue)")!
}
