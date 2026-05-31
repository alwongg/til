# Why I Keep Feature Boundaries Boring in iOS

I’ve built enough iOS screens to know that complexity rarely starts in the UI. It usually leaks in from vague feature boundaries: networking in the view model, formatting in the repository, navigation decisions buried inside async callbacks, and just enough duplication to make every future change annoying.

When I’m doing a Sunday architecture reset, I try to make the boundary between layers aggressively boring. If each layer has one job, the codebase becomes easier to test, easier to onboard into, and much less fragile when product changes direction.

## The legacy shape I try to avoid

This version works for a while, but every concern is mixed together:

```swift
import Foundation

struct Article: Decodable {
    let id: Int
    let title: String
    let isPremium: Bool
}

final class ArticlesViewModel {
    private(set) var titles: [String] = []
    private(set) var shouldShowPaywall = false

    func load() async {
        do {
            let url = URL(string: "https://example.com/articles")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let articles = try JSONDecoder().decode([Article].self, from: data)

            // Presentation formatting is mixed into the loading path.
            titles = articles.map { article in
                article.isPremium ? "🔒 \(article.title)" : article.title
            }

            // Navigation or product policy leaks into state management.
            shouldShowPaywall = articles.contains(where: \ .isPremium)
        } catch {
            titles = ["Failed to load"]
        }
    }
}
```

The problem isn’t that this code is unusually bad. The problem is that it scales badly:

- data fetching, business rules, and presentation formatting live together
- testing requires driving the full async path
- changing the paywall rule means touching UI-facing code
- adding caching or analytics makes the type balloon immediately

## The modern shape I prefer

I split the feature into small layers with clear ownership:

- `Repository` fetches raw feature data
- `UseCase` owns business rules
- `ViewModel` adapts domain output for the screen
- `Coordinator` or router owns navigation decisions

```swift
import Foundation

struct ArticleDTO: Decodable {
    let id: Int
    let title: String
    let isPremium: Bool
}

struct Article: Sendable, Equatable {
    let id: Int
    let title: String
    let access: Access

    enum Access: Sendable {
        case free
        case premium
    }
}

protocol ArticlesRepository {
    func fetchArticles() async throws -> [Article]
}

final class RemoteArticlesRepository: ArticlesRepository {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let baseURL: URL

    init(session: URLSession = .shared,
         decoder: JSONDecoder = JSONDecoder(),
         baseURL: URL) {
        self.session = session
        self.decoder = decoder
        self.baseURL = baseURL
    }

    func fetchArticles() async throws -> [Article] {
        let endpoint = baseURL.appendingPathComponent("articles")
        let (data, _) = try await session.data(from: endpoint)
        let dtos = try decoder.decode([ArticleDTO].self, from: data)

        return dtos.map {
            Article(
                id: $0.id,
                title: $0.title,
                access: $0.isPremium ? .premium : .free
            )
        }
    }
}

struct LoadArticlesUseCase {
    private let repository: ArticlesRepository

    init(repository: ArticlesRepository) {
        self.repository = repository
    }

    struct Result: Sendable, Equatable {
        let articles: [Article]
        let hasPremiumContent: Bool
    }

    func execute() async throws -> Result {
        let articles = try await repository.fetchArticles()
        let hasPremiumContent = articles.contains { $0.access == .premium }
        return Result(articles: articles, hasPremiumContent: hasPremiumContent)
    }
}

struct ArticleRowViewData: Equatable {
    let title: String
    let badge: String?
}

@MainActor
final class ArticlesViewModel: ObservableObject {
    @Published private(set) var rows: [ArticleRowViewData] = []
    @Published private(set) var hasPremiumContent = false
    @Published private(set) var errorMessage: String?

    private let loadArticles: LoadArticlesUseCase

    init(loadArticles: LoadArticlesUseCase) {
        self.loadArticles = loadArticles
    }

    func load() async {
        do {
            let result = try await loadArticles.execute()
            rows = result.articles.map {
                ArticleRowViewData(
                    title: $0.title,
                    badge: $0.access == .premium ? "Premium" : nil
                )
            }
            hasPremiumContent = result.hasPremiumContent
            errorMessage = nil
        } catch {
            rows = []
            hasPremiumContent = false
            errorMessage = "I couldn't load articles."
        }
    }
}
```

## Why this transformation holds up better in production

### 1. Business rules stop hiding in presentation code

The use case answers product questions directly: *does this payload contain premium content?* That rule is now testable without spinning up UI state.

### 2. Repositories stay boring on purpose

I want repositories to be predictable translation layers. Once formatting, entitlement decisions, or navigation starts creeping in, they become hard to reuse and even harder to reason about.

### 3. View models become replaceable

A thin view model is easier to rewrite during SwiftUI refactors. If I move from one screen composition strategy to another, I’m not also dragging networking and policy logic through the migration.

## Migration strategy I actually use

When I’m untangling an existing feature, I don’t do a big-bang rewrite.

1. Extract one repository protocol around the current API call.
2. Move one rule into a use case, even if the first use case is tiny.
3. Convert the view model to consume the use case result.
4. Push navigation side effects outward into a coordinator or parent flow.
5. Add tests at the use case layer first, because that’s where the payoff shows up fastest.

That sequence keeps risk down. I can improve architecture without freezing feature work for a week.

## Production notes I’ve learned the hard way

- Don’t create a use case per button tap just to look “clean.” The boundary matters more than the file count.
- If a repository starts branching on user roles, experiments, or entitlement state, that’s usually a signal the rule belongs above the data layer.
- Keep domain models stable even when API DTOs churn. That buffer pays for itself quickly.
- If navigation depends on async results, model the result cleanly first and let a coordinator decide what route to take next.

## The takeaway I keep coming back to

The architecture pattern itself isn’t the win. The win is making each decision obvious: where data comes from, where policy lives, and where UI adaptation begins. When those answers are boring, the feature usually gets faster to change.
