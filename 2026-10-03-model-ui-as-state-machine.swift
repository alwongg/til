// Quick Concept: Model a screen as one state, not a pile of booleans
//
// When I give a view `isLoading`, `error`, and `items`, I create combinations
// that cannot make sense together. An enum makes the valid UI states explicit
// and lets the compiler force me to handle every transition.

import Foundation

enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(any Error)
}

struct Article: Sendable {
    let title: String
}

@MainActor
final class ArticleViewModel {
    private(set) var state: LoadState<[Article]> = .idle

    func reload(using fetch: () async throws -> [Article]) async {
        state = .loading
        do {
            // Keep the failure at the boundary so rendering stays a pure switch.
            state = .loaded(try await fetch())
        } catch {
            state = .failed(error)
        }
    }

    var screenText: String {
        switch state {
        case .idle: "Pull to refresh"
        case .loading: "Loading…"
        case .loaded(let articles) where articles.isEmpty: "No articles yet"
        case .loaded(let articles): "Showing \(articles.count) articles"
        case .failed(let error): "Try again: \(error.localizedDescription)"
        }
    }
}

@main
struct Demo {
    static func main() async {
        let model = ArticleViewModel()
        await model.reload { [Article(title: "State machines prevent UI drift")] }
        print(model.screenText)
    }
}

// Migration strategy:
// 1. Replace related loading/error/data properties with one state enum.
// 2. Move every transition into the view model.
// 3. Render with an exhaustive switch; add a case only when the product has one.
//
// Production note: keep `loaded([])` separate from `idle`—an empty successful
// response deserves a different UI and analytics event than a request not made.
