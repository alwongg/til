// Architecture Pattern: Coordinator
//
// I use a coordinator when navigation starts leaking from SwiftUI views into
// view models. The view model emits intent; the coordinator owns the route.

import Foundation

@MainActor
protocol Routing: AnyObject {
    func showArticle(id: ArticleID)
    func closeArticle()
}

struct ArticleID: Hashable, Sendable {
    let rawValue: UUID
}

@MainActor
final class FeedViewModel {
    weak var router: (any Routing)?

    func selectedArticle(_ id: ArticleID) {
        // Keeping this intent-focused makes the VM easy to test without a UI.
        router?.showArticle(id: id)
    }
}

@MainActor
final class FeedCoordinator: Routing {
    private(set) var selectedArticle: ArticleID?

    func showArticle(id: ArticleID) {
        selectedArticle = id
    }

    func closeArticle() {
        selectedArticle = nil
    }
}

// In production I inject FeedCoordinator into the composition root, bind its
// selectedArticle to a NavigationStack path, and keep deep-link policy here.
