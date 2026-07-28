// Swift Snippet: Phantom Types for Resource IDs
//
// I use phantom types when two UUID-backed identifiers mean different things.
// The raw value stays lightweight, while the compiler blocks accidental mixing
// of a user ID with an order ID before that mistake reaches a request.

import Foundation

enum UserTag {}
enum OrderTag {}

struct ID<Tag>: Hashable, Sendable, CustomStringConvertible {
    let rawValue: UUID

    init() {
        rawValue = UUID()
    }

    init(_ rawValue: UUID) {
        self.rawValue = rawValue
    }

    var description: String { rawValue.uuidString }
}

struct UserProfileRequest: Sendable {
    let userID: ID<UserTag>
}

struct OrderDetailRequest: Sendable {
    let orderID: ID<OrderTag>
}

func makeRequests() -> (UserProfileRequest, OrderDetailRequest) {
    let user = ID<UserTag>()
    let order = ID<OrderTag>()

    // UserProfileRequest(userID: order) does not compile: exactly the guard I want.
    return (UserProfileRequest(userID: user), OrderDetailRequest(orderID: order))
}
