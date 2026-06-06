import Foundation

/*
 # From Bool Soup to Phase-Driven View State

 I still run into view models that accumulate `isLoading`, `hasLoadedOnce`, `isEmpty`, and `errorMessage` until the screen becomes a pile of overlapping conditions.

 That shape usually works for the first happy path, then starts lying as soon as I add pull-to-refresh, retries, stale cached data, or a second async dependency.

 On iOS teams, one of the quickest quality upgrades I can make is replacing boolean-heavy screen state with a single phase enum that describes what the UI should render.

 ## Legacy approach

 This is the version I try to retire early:

 ```swift
 @MainActor
 final class FeedViewModel {
     var isLoading = false
     var hasLoadedOnce = false
     var items: [Article] = []
     var errorMessage: String?

     func load() async {
         isLoading = true
         errorMessage = nil

         do {
             items = try await api.fetchArticles()
             hasLoadedOnce = true
         } catch {
             errorMessage = error.localizedDescription
         }

         isLoading = false
     }
 }
 ```

 It looks harmless, but I eventually pay for it with impossible combinations like:
 - `isLoading == false` while `items` is stale and `errorMessage` is still set
 - `hasLoadedOnce == true` even though the latest refresh failed and the screen needs a different affordance
 - branching SwiftUI bodies that quietly drift from product intent

 ## Modern approach

 I prefer one renderable state model that makes invalid combinations hard to express.
 */

struct Article: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
}

protocol ArticleRepository: Sendable {
    func fetchArticles() async throws -> [Article]
}

enum FeedError: Error, LocalizedError, Sendable {
    case offline

    var errorDescription: String? {
        switch self {
        case .offline:
            return "I couldn't reach the feed."
        }
    }
}

struct DemoArticleRepository: ArticleRepository {
    let shouldFail: Bool

    func fetchArticles() async throws -> [Article] {
        try await Task.sleep(for: .milliseconds(50))

        if shouldFail {
            throw FeedError.offline
        }

        return [
            Article(id: UUID(), title: "Phase enums remove contradictory UI states"),
            Article(id: UUID(), title: "Refresh logic gets simpler when state is explicit")
        ]
    }
}

enum FeedPhase: Equatable, Sendable {
    case idle
    case loading(previous: [Article])
    case loaded([Article])
    case empty
    case failed(message: String, previous: [Article])

    var articles: [Article] {
        switch self {
        case .idle, .empty:
            return []
        case .loading(let previous), .failed(_, let previous):
            return previous
        case .loaded(let articles):
            return articles
        }
    }

    var isShowingInlineSpinner: Bool {
        if case .loading(let previous) = self {
            return !previous.isEmpty
        }
        return false
    }
}

@MainActor
final class FeedViewModel {
    private let repository: any ArticleRepository

    private(set) var phase: FeedPhase = .idle

    init(repository: any ArticleRepository) {
        self.repository = repository
    }

    func load() async {
        let previousArticles = phase.articles
        phase = .loading(previous: previousArticles)

        do {
            let articles = try await repository.fetchArticles()
            phase = articles.isEmpty ? .empty : .loaded(articles)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? "Unknown error"
            phase = .failed(message: message, previous: previousArticles)
        }
    }

    var screenTitle: String {
        switch phase {
        case .idle:
            return "Feed"
        case .loading(let previous):
            return previous.isEmpty ? "Loading feed…" : "Refreshing feed…"
        case .loaded(let articles):
            return "Feed (\(articles.count))"
        case .empty:
            return "No articles yet"
        case .failed:
            return "Feed unavailable"
        }
    }
}

@main
enum Demo {
    static func main() async {
        let successViewModel = FeedViewModel(repository: DemoArticleRepository(shouldFail: false))
        await successViewModel.load()
        print(successViewModel.screenTitle)
        print(successViewModel.phase.articles.map(\.title).joined(separator: " | "))

        let failureViewModel = FeedViewModel(repository: DemoArticleRepository(shouldFail: true))
        await failureViewModel.load()
        print(failureViewModel.screenTitle)
        print(failureViewModel.phase)
    }
}

/*
 What I like about this shape:
 - the UI renders from one source of truth instead of recombining flags
 - refreshes can preserve previous data without pretending the request succeeded
 - retry logic gets easier because the current phase already describes what the user is seeing
 - product discussions become cleaner because each state maps to a specific screen experience

 ## Migration strategy

 I usually move toward this in four passes:

 1. Write down every user-visible screen state before touching code.
 2. Collapse overlapping booleans into a single enum with associated values for preserved context.
 3. Add small computed properties on the phase when the view needs derived display signals.
 4. Update tests to assert phase transitions instead of checking a handful of unrelated flags.

 ## Production notes

 - I keep network status and render state separate until the UI actually needs them fused.
 - If a screen can show stale content during refresh, I model that explicitly instead of hiding it behind `isLoading`.
 - This pattern scales especially well in SwiftUI because `switch`ing over phase keeps the body honest.
 - When a screen starts feeling brittle, phase modeling is one of the first simplifications I reach for.
 */
