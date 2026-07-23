// I use a labeled safe subscript when an out-of-range index is a valid UI state,
// not a programmer error. It keeps collection access explicit at call sites.

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct SearchResult {
    let title: String
}

struct SearchResultsViewModel {
    private let results: [SearchResult]

    init(results: [SearchResult]) {
        self.results = results
    }

    func title(forVisibleRow row: Int) -> String {
        // A diffable-data-source snapshot can change between layout and lookup.
        // Returning a fallback avoids treating that timing gap as a crash-worthy bug.
        results[safe: row]?.title ?? "Result unavailable"
    }
}
