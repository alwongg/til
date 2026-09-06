// Sendable Snapshots: the Smallest Useful Concurrency Boundary
//
// Quick concept
// I keep UI models on @MainActor and avoid letting mutable reference types
// cross into background work. When a task needs a value, I take a small,
// immutable Sendable snapshot instead of passing the whole model.
//
// Legacy approach
// Capturing a reference-backed view model inside Task.detached looks convenient,
// but it couples the worker to UI-owned mutable state and trips strict
// concurrency checking for a good reason.
//
// Modern approach
// Make the work input a value type containing only what the worker needs.
// The background task receives stable data; the main actor owns applying results.
//
// Migration strategy
// 1. Identify the exact fields read by the background task.
// 2. Put those fields in a Sendable snapshot.
// 3. Return another Sendable value, then update UI on the main actor.
//
// Production note
// A snapshot is intentionally stale the moment it is created. That is usually
// correct for rendering, indexing, and upload preparation. If freshness matters,
// version the snapshot and discard results that no longer match current state.

import Foundation

struct SearchSnapshot: Sendable {
    let query: String
    let localeIdentifier: String
    let revision: Int
}

struct SearchResult: Sendable {
    let revision: Int
    let normalizedQuery: String
}

@MainActor
final class SearchViewModel {
    private var revision = 0
    private(set) var query = ""

    func update(query: String) async {
        revision += 1
        self.query = query

        let snapshot = SearchSnapshot(
            query: query,
            localeIdentifier: Locale.current.identifier,
            revision: revision
        )

        let result = await Task.detached(priority: .userInitiated) {
            // The detached task owns only immutable, Sendable input.
            SearchResult(
                revision: snapshot.revision,
                normalizedQuery: snapshot.query
                    .folding(options: .diacriticInsensitive, locale: Locale(identifier: snapshot.localeIdentifier))
                    .lowercased()
            )
        }.value

        // A newer keystroke may have arrived while normalization ran.
        guard result.revision == revision else { return }
        print("Search for: \(result.normalizedQuery)")
    }
}

@main
struct Demo {
    static func main() async {
        let model = SearchViewModel()
        await model.update(query: "Crème Brûlée")
    }
}
