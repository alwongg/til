// iOS Tip: Make Collection Bounds Explicit
//
// I use this when an index comes from user input, a diff, or an API response.
// Returning nil keeps an absent element distinct from a valid optional element.

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct RecentSearches {
    private var terms = ["Swift", "SwiftUI", "Concurrency"]

    mutating func select(at index: Int) -> String? {
        guard let term = terms[safe: index] else {
            // I can log or ignore a stale UI index without crashing the screen.
            return nil
        }
        terms.remove(at: index)
        return term
    }
}

func visibleSearch(at index: Int, in searches: [String]) -> String {
    searches[safe: index] ?? "No recent search"
}
