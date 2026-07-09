import Foundation

/// I use `@discardableResult` when a helper returns something useful,
/// but the common path should stay warning-free.
struct AnalyticsClient {
    @discardableResult
    func track(
        _ event: String,
        metadata: [String: String] = [:]
    ) -> UUID {
        let id = UUID()
        print("Tracked \(event) id=\(id.uuidString) metadata=\(metadata)")
        return id
    }
}

@main
enum Demo {
    static func main() {
        let analytics = AnalyticsClient()

        // Most call sites can fire-and-forget without a warning.
        analytics.track("screen_view")

        // I still get a strongly typed value back when I need to correlate work.
        let checkoutID = analytics.track(
            "checkout_started",
            metadata: ["source": "paywall"]
        )

        print("Correlation id: \(checkoutID.uuidString)")
    }
}
