import Foundation

// Tip: @discardableResult for opt-in return values
// I use this when a helper usually behaves like fire-and-forget,
// but I still want tests or advanced call sites to inspect the return value.

struct AnalyticsEvent {
    let name: String
    let metadata: [String: String]
}

struct AnalyticsClient {
    @discardableResult
    func track(_ event: AnalyticsEvent) -> UUID {
        // I still return the identifier so tests can assert on it.
        UUID()
    }
}

enum CheckoutFlow {
    static func openCart(client: AnalyticsClient) {
        // Most production call sites do not need the returned UUID.
        client.track(.init(name: "cart_opened", metadata: ["surface": "checkout"]))
    }

    static func submitOrder(client: AnalyticsClient) -> UUID {
        // When I do care, the return value is still there.
        client.track(.init(name: "order_submitted", metadata: ["result": "success"]))
    }
}
