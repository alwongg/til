// iOS Tip — Safe Array Subscripts
//
// I use a safe subscript at UI boundaries where stale indexes are normal:
// diffable-data-source snapshots, async callbacks, and user selections can all
// outlive the collection they originally referenced. Returning nil makes that
// uncertainty explicit instead of turning it into a production crash.

import Foundation

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct Product: Identifiable {
    let id: UUID
    let name: String
}

@main
struct SafeSubscriptDemo {
    static func main() {
        let products = [
            Product(id: UUID(), name: "Mochi Treats"),
            Product(id: UUID(), name: "USB-C Cable")
        ]

        let selectedIndex = 3 // This can be stale after a snapshot update.
        guard let product = products[safe: selectedIndex] else {
            return // The screen can dismiss or show an empty state safely.
        }

        print("Showing \(product.name)")
    }
}
