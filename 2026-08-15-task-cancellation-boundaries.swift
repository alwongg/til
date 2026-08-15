import Foundation

// Quick Concept: cancellation is cooperative, so I make it explicit at
// meaningful boundaries rather than assuming cancelling a Task stops its work.
struct SearchService {
    func results(for query: String) async throws -> [String] {
        try Task.checkCancellation()

        // This stands in for a cancellable URLSession request.
        try await Task.sleep(for: .milliseconds(250))
        try Task.checkCancellation()

        return ["\(query) result 1", "\(query) result 2"]
    }
}

@MainActor
final class SearchViewModel {
    private let service = SearchService()
    private var searchTask: Task<Void, Never>?

    var results: [String] = []

    func search(_ query: String) {
        searchTask?.cancel()

        searchTask = Task { [service] in
            do {
                // Debouncing belongs inside the task so a newer query cancels it too.
                try await Task.sleep(for: .milliseconds(300))
                let loaded = try await service.results(for: query)
                guard !Task.isCancelled else { return }
                results = loaded
            } catch is CancellationError {
                // Cancellation is expected control flow, not a user-facing error.
            } catch {
                results = []
            }
        }
    }

    deinit {
        searchTask?.cancel()
    }
}

@main
enum Demo {
    static func main() async {
        let model = SearchViewModel()
        model.search("swift")
        try? await Task.sleep(for: .seconds(1))
        print(model.results)
    }
}
