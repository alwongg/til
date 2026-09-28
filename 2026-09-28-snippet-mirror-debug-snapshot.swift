// Swift Snippet — Mirror debug snapshots
//
// I use reflection at diagnostic boundaries, not as app logic. It lets me capture
// useful field names in logs without coupling a debug helper to every model type.

import Foundation

struct CheckoutAttempt {
    let orderID: UUID
    let amount: Decimal
    let isRetry: Bool
}

func debugSnapshot(of value: Any) -> [String: String] {
    Mirror(reflecting: value).children.reduce(into: [:]) { snapshot, child in
        // Labels are optional for tuple elements, so preserve a stable fallback.
        let key = child.label ?? "item_\(snapshot.count)"
        snapshot[key] = String(describing: child.value)
    }
}

@main
enum Demo {
    static func main() {
        let attempt = CheckoutAttempt(
            orderID: UUID(uuidString: "F0930B2B-BD93-4C0B-8D60-DC2B21CCB77B")!,
            amount: 19.99,
            isRetry: true
        )

        let snapshot = debugSnapshot(of: attempt)
        print(snapshot["isRetry"] ?? "missing")
    }
}
