import Foundation

/*
Quick Concept — Cancellation as Control Flow

I still see a lot of iOS code treat cancellation like a failure path that needs retry banners,
error toasts, or noisy logs. In modern Swift concurrency, cancellation is usually just control
flow. The user scrolled away. The screen disappeared. A newer request made the older one irrelevant.

Legacy approach
- Start a request and let it run even after the UI no longer needs it.
- Surface cancellation beside real failures, which pollutes analytics and wastes retries.
- Scatter `Task.isCancelled` checks without a clear boundary for what should happen next.

Modern approach
- Check cancellation at suspension boundaries.
- Throw `CancellationError()` early and let the caller decide whether silence is the right UX.
- Separate cancellation from transport failures so metrics stay honest.

Migration strategy
1. Identify async entry points owned by view lifecycle or user intent.
2. Add `Task.checkCancellation()` before expensive work and after awaited dependencies.
3. Catch `CancellationError` at the edge and intentionally do nothing.
4. Keep real failures observable and actionable.

Production notes
- I log cancellation counts separately from errors.
- I avoid retrying cancelled work automatically because a newer task usually replaced it.
- I use cancellation to keep feeds, search, and image loading responsive under rapid UI churn.
*/

struct SearchService {
    enum SearchError: Error {
        case transport
    }

    func search(query: String) async throws -> [String] {
        try Task.checkCancellation()

        // Simulate dependency latency before doing any decoding or mapping work.
        try await Task.sleep(for: .milliseconds(120))
        try Task.checkCancellation()

        guard query != "offline" else {
            throw SearchError.transport
        }

        return ["Result for: \(query)"]
    }
}

@MainActor
final class SearchViewModel {
    private let service = SearchService()
    private(set) var results: [String] = []
    private(set) var errorMessage: String?

    func load(query: String) async {
        do {
            results = try await service.search(query: query)
            errorMessage = nil
        } catch is CancellationError {
            // Cancellation is expected control flow here.
            // I deliberately keep the current UI state unchanged.
        } catch {
            errorMessage = "Couldn't load search results."
        }
    }
}
