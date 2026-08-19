// Strategy Pattern: make a changing policy explicit
//
// I reach for Strategy when a feature has one stable workflow but a policy that
// changes independently. Keeping the policy as a value makes it easy to select,
// test, and replace without branching through the caller.

import Foundation

struct SearchResult: Equatable {
    let title: String
    let relevance: Int
    let updatedAt: Date
}

protocol ResultOrdering {
    func sorted(_ results: [SearchResult]) -> [SearchResult]
}

struct RelevanceOrdering: ResultOrdering {
    func sorted(_ results: [SearchResult]) -> [SearchResult] {
        results.sorted { $0.relevance > $1.relevance }
    }
}

struct RecencyOrdering: ResultOrdering {
    func sorted(_ results: [SearchResult]) -> [SearchResult] {
        results.sorted { $0.updatedAt > $1.updatedAt }
    }
}

struct SearchPresenter {
    // The presenter owns the workflow; the injected strategy owns the policy.
    let ordering: any ResultOrdering

    func display(_ results: [SearchResult]) -> [SearchResult] {
        ordering.sorted(results)
    }
}

// I inject RelevanceOrdering for a ranked search screen and RecencyOrdering
// for a "what changed" view. Each policy is independently unit-testable.
