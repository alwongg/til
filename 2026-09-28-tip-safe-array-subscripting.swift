import Foundation

// I use this when an absent element is normal UI state, not an exception.
extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct RecentSearches {
    private let terms: [String]

    init(terms: [String]) {
        self.terms = terms
    }

    func title(at position: Int) -> String {
        // Returning a product fallback keeps the view declarative and prevents
        // every caller from re-implementing bounds checks.
        terms[safe: position] ?? "No recent search"
    }
}

@main
struct Demo {
    static func main() {
        let searches = RecentSearches(terms: ["Swift", "SwiftUI"])
        print(searches.title(at: 1))
        print(searches.title(at: 2))
    }
}
