import Foundation

/*:
 # Feature Boundaries with Use Cases

 I still see a lot of iOS codebases call themselves MVVM while the ViewModel quietly owns networking,
 caching, analytics, and navigation. That works until one screen starts carrying product policy.
 My current upgrade path is to keep the ViewModel thin and move the business decision into a use case.

 ## Legacy approach
 A fat ViewModel loads remote data, decides fallback behavior, and tells the coordinator where to go.
 The screen is easy to start, but hard to test because UI state and product rules are fused together.

 ## Modern approach
 I split the feature into five boundaries:
 - Model: `Article`
 - Repository: data access contract
 - Use case: product decision about what to show
 - ViewModel: screen-facing state only
 - Route: navigation intent emitted as data

 ## Migration strategy
 1. Keep the existing ViewModel API stable.
 2. Extract one decision branch into a `LoadFeaturedArticleUseCase`.
 3. Replace direct coordinator calls with a route enum.
 4. Move retry, cache, and analytics concerns behind injected dependencies.

 ## Production notes
 - Repositories should hide transport details, not just rename `URLSession`.
 - Use cases are where I encode product rules like fallback ordering and empty-state behavior.
 - Route enums make deep-link and test coverage much easier than coordinator calls buried in methods.
 - `@MainActor` on the ViewModel keeps UI mutation honest while async work stays in the use case.
 */

struct Article: Equatable, Sendable {
    let id: UUID
    let title: String
    let isFeatured: Bool
}

protocol ArticleRepository: Sendable {
    func fetchArticles() async throws -> [Article]
}

struct InMemoryArticleRepository: ArticleRepository {
    let articles: [Article]

    func fetchArticles() async throws -> [Article] {
        articles
    }
}

struct LoadFeaturedArticleUseCase: Sendable {
    let repository: ArticleRepository

    func execute() async throws -> Article? {
        let articles = try await repository.fetchArticles()

        // Product policy lives here: prefer featured content, then fall back to the first article.
        return articles.first(where: \.isFeatured) ?? articles.first
    }
}

enum FeaturedRoute: Equatable, Sendable {
    case articleDetail(id: UUID)
    case emptyState
}

@MainActor
final class FeaturedArticleViewModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded(title: String)
        case empty
        case failed(message: String)
    }

    private let loadFeaturedArticle: LoadFeaturedArticleUseCase
    private(set) var state: State = .idle
    private(set) var pendingRoute: FeaturedRoute?

    init(loadFeaturedArticle: LoadFeaturedArticleUseCase) {
        self.loadFeaturedArticle = loadFeaturedArticle
    }

    func refresh() async {
        state = .loading

        do {
            guard let article = try await loadFeaturedArticle.execute() else {
                state = .empty
                pendingRoute = .emptyState
                return
            }

            state = .loaded(title: article.title)
            pendingRoute = .articleDetail(id: article.id)
        } catch {
            // The ViewModel translates domain failure into presentation language.
            state = .failed(message: "Unable to load the featured article right now.")
            pendingRoute = nil
        }
    }
}
