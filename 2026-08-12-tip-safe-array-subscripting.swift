// Today I avoid "index out of range" crashes at collection boundaries.
// An optional subscript makes the failure mode explicit at the call site.

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

    func term(at position: Int) -> String {
        // I choose a product fallback rather than letting a stale UI index crash.
        terms[safe: position] ?? "No recent search"
    }
}

enum SafeSubscriptExample {
    static func run() {
        let searches = RecentSearches(terms: ["Swift concurrency", "Observation"])
        print(searches.term(at: 1))
        print(searches.term(at: 99))
    }
}

// I still use normal subscripting when an invalid index is a programmer error.
// I use [safe:] for user-driven, asynchronous, or stale-index boundaries.
