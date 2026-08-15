// Architecture Pattern: Feature Pipeline — Model → Repository → Use Case → ViewModel
// I keep each feature's rules pointed inward so SwiftUI stays replaceable.

import Foundation

struct Article: Identifiable, Decodable, Sendable {
    let id: UUID
    let title: String
}

protocol ArticleRepository: Sendable {
    func fetchFeatured() async throws -> [Article]
}

struct LoadFeaturedArticles: Sendable {
    let repository: any ArticleRepository

    func callAsFunction() async throws -> [Article] {
        // This is where I keep product rules, before a view can depend on them.
        try await repository.fetchFeatured().filter { !$0.title.isEmpty }
    }
}

@MainActor
final class FeaturedArticlesViewModel {
    private let loadFeatured: LoadFeaturedArticles
    private(set) var articles: [Article] = []
    private(set) var errorMessage: String?

    init(loadFeatured: LoadFeaturedArticles) {
        self.loadFeatured = loadFeatured
    }

    func refresh() async {
        do {
            articles = try await loadFeatured()
            errorMessage = nil
        } catch {
            // The view receives presentation state, not transport details.
            errorMessage = "Couldn’t load featured articles."
        }
    }
}
