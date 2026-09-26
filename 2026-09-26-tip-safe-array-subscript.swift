// # Tip: Make Array Access Explicit at the Boundary
//
// I use a safe subscript when an index arrives from UI state, a deep link, or a
// server response. It makes the optionality visible where the index is uncertain
// instead of scattering bounds checks through a view model.
//
// I keep the standard subscript for invariants: an out-of-range index there should
// still fail loudly during development. This helper is for genuinely optional data.

import Foundation

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct Product: Equatable {
    let name: String
}

struct ProductPicker {
    private let products = [
        Product(name: "Mac"),
        Product(name: "iPhone")
    ]

    func product(forSelectedRow row: Int?) -> Product? {
        guard let row else { return nil }
        return products[safe: row]
    }
}

@main
struct Demo {
    static func main() {
        let picker = ProductPicker()
        assert(picker.product(forSelectedRow: 1)?.name == "iPhone")
        assert(picker.product(forSelectedRow: 8) == nil)
    }
}
