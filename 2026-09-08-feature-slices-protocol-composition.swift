// Architecture Patterns Evolved: From a God ViewModel to a Feature Slice
//
// I used to let a screen's ViewModel own networking, mapping, retry policy,
// and navigation decisions. It was fast to start, but every new state made the
// file harder to test and reuse. My modern boundary is intentionally small:
// View -> ViewModel -> UseCase -> Repository.
//
// Legacy approach:
// A ViewModel calls URLSession directly and turns transport errors into UI
// state. That couples rendering tests to HTTP details and makes the same fetch
// logic difficult to share with widgets or another feature.
//
// Modern approach:
// The repository owns data access; the use case expresses one product action;
// the ViewModel only reduces that action into screen state.

import Foundation

struct Article: Equatable, Sendable {
    let id: UUID
    let title: String
}

protocol ArticleRepository: Sendable {
    func featuredArticles() async throws -> [Article]
}

struct LoadFeaturedArticles: Sendable {
    private let repository: any ArticleRepository

    init(repository: any ArticleRepository) {
        self.repository = repository
    }

    func callAsFunction() async throws -> [Article] {
        // Product rules belong here, so every caller gets the same ordering.
        try await repository.featuredArticles().sorted { $0.title < $1.title }
    }
}

@MainActor
final class FeaturedArticlesViewModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded([Article])
        case failed(String)
    }

    private let loadFeaturedArticles: LoadFeaturedArticles
    private(set) var state: State = .idle

    init(loadFeaturedArticles: LoadFeaturedArticles) {
        self.loadFeaturedArticles = loadFeaturedArticles
    }

    func load() async {
        state = .loading
        do {
            state = .loaded(try await loadFeaturedArticles())
        } catch {
            // The UI gets a stable state rather than knowing transport errors.
            state = .failed("Could not load featured articles.")
        }
    }
}

// Migration strategy:
// 1. Extract the existing network call behind ArticleRepository.
// 2. Move one screen-level rule into LoadFeaturedArticles.
// 3. Inject the use case into the ViewModel and test its state transitions.
// 4. Repeat feature by feature; avoid a repo-wide rewrite.
//
// Production notes:
// Keep repository protocols feature-scoped, inject a fake repository in tests,
// and add caching/retry beneath the use case boundary when requirements demand it.
