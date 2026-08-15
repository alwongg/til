// I reach for lazy sequences when I only need a small result from a large collection.
// This keeps intermediate arrays out of the hot path and stops work as soon as `prefix` is satisfied.
import Foundation

struct Product {
    let id: Int
    let isAvailable: Bool
    let priceInCents: Int
}

func cheapestAvailableIDs(in products: [Product], limit: Int) -> [Int] {
    products.lazy
        .filter(\.isAvailable)
        .sorted { $0.priceInCents < $1.priceInCents }
        .prefix(limit)
        .map(\.id)
}

func previewIDs(in products: [Product], limit: Int) -> [Int] {
    // `prefix` before `map` means I transform only the values I will display.
    products.lazy
        .filter(\.isAvailable)
        .prefix(limit)
        .map(\.id)
}

// Lazy evaluation removes intermediate allocations, but it cannot make `sorted` lazy:
// sorting must inspect every candidate. I use it for short-circuiting pipelines, then profile
// before claiming a performance win in a production screen.
