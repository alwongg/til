import Foundation

/*
 # From Fire-and-Forget Search to Cancellation-Aware Tasks

 One quick concept I keep revisiting in iOS codebases is this: async work is part of state, not a side effect I can ignore.

 Search is where this bites first. A user types "s", then "sw", then "swift". If I launch a new task for each keystroke and let all of them finish whenever they want, stale responses can overwrite the newest intent.

 ## Legacy approach

 This is the shape that usually causes flicker and out-of-order UI updates:

 ```swift
 final class SearchViewModel {
     func queryChanged(to query: String) {
         Task {
             results = try await api.search(query)
         }
     }
 }
 ```

 It feels compact, but it quietly loses control over lifecycle.

 ## Modern approach

 I prefer to keep a handle to the active task and cancel it before starting replacement work.
 */

struct SearchResult: Equatable, Sendable, CustomStringConvertible {
    let title: String

    var description: String { title }
}

protocol SearchServing: Sendable {
    func search(query: String) async throws -> [SearchResult]
}

enum SearchError: Error {
    case emptyQuery
}

actor DemoSearchService: SearchServing {
    func search(query: String) async throws -> [SearchResult] {
        guard !query.isEmpty else {
            throw SearchError.emptyQuery
        }

        let delay: Duration = switch query {
        case "s": .milliseconds(140)
        case "sw": .milliseconds(90)
        default: .milliseconds(40)
        }

        try await Task.sleep(for: delay)
        try Task.checkCancellation()

        return [
            SearchResult(title: "\(query) basics"),
            SearchResult(title: "\(query) production notes")
        ]
    }
}

@MainActor
final class SearchViewModel {
    private let service: any SearchServing
    private var searchTask: Task<Void, Never>?

    private(set) var latestQuery: String = ""
    private(set) var results: [SearchResult] = []
    private(set) var status: String = "idle"

    init(service: any SearchServing) {
        self.service = service
    }

    func queryChanged(to query: String) {
        latestQuery = query
        searchTask?.cancel()

        guard !query.isEmpty else {
            results = []
            status = "idle"
            return
        }

        status = "searching \(query)"

        searchTask = Task { [service] in
            do {
                let found = try await service.search(query: query)
                try Task.checkCancellation()
                results = found
                status = "rendering \(query)"
            } catch is CancellationError {
                // Cancellation is expected replacement work, not a user-facing error.
            } catch {
                results = []
                status = "failed \(query): \(error)"
            }
        }
    }

    func waitForCurrentSearch() async {
        await searchTask?.value
    }
}

@main
struct Demo {
    static func main() async {
        let viewModel = SearchViewModel(service: DemoSearchService())

        viewModel.queryChanged(to: "s")
        viewModel.queryChanged(to: "sw")
        viewModel.queryChanged(to: "swift")

        await viewModel.waitForCurrentSearch()

        print("latestQuery=\(viewModel.latestQuery)")
        print("status=\(viewModel.status)")
        print("results=\(viewModel.results.map(\.title).joined(separator: " | "))")
    }
}

/*
 What I like about this shape:
 - only the newest intent gets to update UI state
 - cancellation becomes a normal control-flow path instead of a bug
 - replacing work is explicit, so debouncing or retry policies have somewhere to live
 - this scales from search to image loading, form validation, and AI-assisted text generation

 ## Migration strategy

 I usually move toward this in four passes:

 1. Find the entry points that launch untracked `Task {}` blocks from UI events.
 2. Store the active task on the owning type and cancel it before replacement work starts.
 3. Treat `CancellationError` as expected flow, not a surfaced failure.
 4. Add tests for stale-result protection so the newest query always wins.

 ## Production notes

 - Cancellation is cooperative. I still need my async stack to check for it at useful boundaries.
 - If multiple consumers need the same search result, I combine this pattern with coalescing rather than picking one or the other.
 - For SwiftUI, this concept pairs well with `.task(id:)` because identity changes naturally express replacement work.
 - The main win is correctness: I stop rendering yesterday's answer for today's intent.
 */
