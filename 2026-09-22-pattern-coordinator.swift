// Coordinator Pattern: keep navigation decisions out of feature screens.
// I let screens express an intent; the coordinator owns the route and its dependencies.

import Foundation

struct Article: Sendable, Equatable {
    let id: UUID
    let title: String
}

enum ArticleRoute: Sendable, Equatable {
    case detail(Article)
    case settings
}

protocol ArticleRouting: AnyObject {
    func show(_ route: ArticleRoute)
}

final class ArticleListViewModel {
    private weak var router: (any ArticleRouting)?

    init(router: any ArticleRouting) {
        self.router = router
    }

    func didSelect(_ article: Article) {
        // The feature reports intent, so it remains testable without a navigation stack.
        router?.show(.detail(article))
    }

    func didTapSettings() {
        router?.show(.settings)
    }
}

final class ArticleCoordinator: ArticleRouting {
    private(set) var routes: [ArticleRoute] = []

    func start() -> ArticleListViewModel {
        ArticleListViewModel(router: self)
    }

    func show(_ route: ArticleRoute) {
        // Map routes to UIKit/SwiftUI presentation here; keep transitions centralized.
        routes.append(route)
    }
}

// Production note: make routes value types and inject the coordinator protocol.
// That lets unit tests assert intents while UIKit or SwiftUI stays at the app boundary.
