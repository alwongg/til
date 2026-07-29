# Tip: Make Array Access Explicitly Optional

I treat array indexing as an untrusted boundary. Collection indices are easy to get right in a controlled loop, but UI state, deep links, and async updates regularly hand me stale offsets. A tiny safe subscript keeps the failure mode in Swift's type system: `nil`, not a crash.

```swift
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

@MainActor
final class ProductSelectionModel {
    private(set) var products: [Product] = []

    func selectProduct(at displayedOffset: Int) -> Product? {
        // The displayed list can change before a tap is handled.
        products[safe: displayedOffset]
    }

    func replaceProducts(with products: [Product]) {
        self.products = products
    }
}
```

`Collection` matters here: this works for more than `[Element]`, and it does not pretend every collection starts at zero. I use it at input boundaries, then unwrap once and continue with a valid model. It is not a substitute for fixing a broken index invariant; it is a deliberate way to make recoverable stale-state paths safe.
