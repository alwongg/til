// Architecture Patterns Evolved: Make the Use Case the Stable Center
//
// I used to let a ViewModel call URLSession directly. It was fast to ship, but
// tests had to mock networking details and a screen change could rewrite data
// logic. My modern boundary is smaller: the ViewModel asks a use case for an
// outcome; the use case depends on a protocol; infrastructure implements it.
//
// Legacy approach
// A ViewModel owns request construction, decoding, retry policy, and UI state.
// The UI layer therefore knows too much about transport and persistence.
//
// Modern approach
// The use case expresses one product action. Repository is the seam for data
// sources. The ViewModel translates a domain result into presentation state.
// This is not ceremony for its own sake: it keeps SwiftUI previews and tests
// deterministic while the app can change its backend independently.

import Foundation

struct Article: Codable, Equatable, Sendable, Identifiable {
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
        // Product rules live here, before presentation gets involved.
        try await repository.featuredArticles()
            .filter { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
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
            // Presentation decides wording; the repository never leaks UI text.
            state = .failed("Could not load featured articles.")
        }
    }
}

// Migration strategy
// 1. Extract the existing fetch behind ArticleRepository without changing UI.
// 2. Introduce LoadFeaturedArticles and move product rules into it.
// 3. Inject the use case into the ViewModel; keep URLSession in the repository.
// 4. Add an in-memory repository for tests and SwiftUI previews.
//
// Production notes
// Keep use cases small and named after user intent. Inject protocols at the
// composition root, not via global singletons. Add caching, telemetry, and
// retry behavior in infrastructure or dedicated policies so feature code stays
// readable. I reach for another layer only when it creates a real seam.