import Foundation

// TIL: Safe array subscripting
// I use this at UI boundaries where stale indexes are normal—not exceptional.

extension Collection {
    /// Returns nil instead of trapping when an index became invalid.
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct RecentSearches {
    private let terms = ["Swift concurrency", "Observation"]

    func title(forRow row: Int) -> String {
        // A deleted row can race an animation or a diffable-data-source snapshot.
        // Falling back here keeps that recoverable state out of crash reporting.
        terms[safe: row] ?? "Search unavailable"
    }

    func remove(at row: Int) -> [String] {
        guard terms[safe: row] != nil else { return terms }
        return terms.enumerated().compactMap { offset, term in
            offset == row ? nil : term
        }
    }
}

@main
struct Demo {
    static func main() {
        let searches = RecentSearches()
        print(searches.title(forRow: 4))
    }
}
