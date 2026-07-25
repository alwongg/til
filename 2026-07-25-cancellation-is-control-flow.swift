// Quick Concept: Treat Cancellation as Control Flow
//
// I keep cancellation separate from failure. A cancelled search is usually a
// perfectly valid product decision: the user typed again, navigated away, or
// pulled to refresh. I let it escape instead of turning it into an alert.

import Foundation

enum SearchError: Error {
    case offline
}

struct SearchService {
    func search(_ query: String) async throws -> [String] {
        try await Task.sleep(for: .milliseconds(250))
        try Task.checkCancellation()

        guard !query.isEmpty else { return [] }
        return ["Result for \(query)"]
    }
}

@MainActor
final class SearchViewModel {
    private let service = SearchService()
    private var searchTask: Task<Void, Never>?

    private(set) var results: [String] = []
    private(set) var errorMessage: String?

    func queryChanged(to query: String) {
        searchTask?.cancel()

        searchTask = Task {
            do {
                results = try await service.search(query)
                errorMessage = nil
            } catch is CancellationError {
                // I deliberately preserve the current UI: cancellation is expected.
            } catch {
                errorMessage = "Search failed. Try again."
            }
        }
    }

    deinit { searchTask?.cancel() }
}

// Migration note: start by adding Task.checkCancellation() after expensive
// suspension points. Then audit catch blocks so cancellation never gets mapped
// to a generic error state. In production, this prevents stale requests from
// overwriting newer results and keeps telemetry focused on real failures.
