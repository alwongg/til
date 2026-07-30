import Foundation

/// # Coordinator Pattern: Keep Navigation Out of Features
///
/// I use a coordinator when a flow crosses multiple screens. A view model owns
/// state and intent; the coordinator decides the next destination. That keeps
/// navigation policy testable without loading UI frameworks.
protocol AccountRouting: AnyObject {
    func showProfile(userID: UUID)
    func showSettings()
}

enum AccountRoute {
    case profile(UUID)
    case settings
}

final class AccountCoordinator: AccountRouting {
    private(set) var routeHistory: [AccountRoute] = []

    func showProfile(userID: UUID) {
        routeHistory.append(.profile(userID))
    }

    func showSettings() {
        routeHistory.append(.settings)
    }
}

final class AccountViewModel {
    private weak var router: (any AccountRouting)?

    init(router: any AccountRouting) {
        self.router = router
    }

    func didTapProfile(id: UUID) { router?.showProfile(userID: id) }
    func didTapSettings() { router?.showSettings() }
}

@main
struct Demo {
    static func main() {
        let coordinator = AccountCoordinator()
        let viewModel = AccountViewModel(router: coordinator)
        viewModel.didTapProfile(id: UUID())
        print(coordinator.routeHistory.count) // Navigation is observable in tests.
    }
}

/// **Why I reach for this:** feature code asks for an outcome, not a presentation
/// mechanism. The coordinator can later translate routes to SwiftUI paths, UIKit
/// pushes, deep links, or an onboarding gate without changing the view model.
///
/// **Production note:** I inject the routing protocol rather than a concrete
/// coordinator. My view-model tests use a tiny recording router to assert routes
/// and avoid coupling business tests to navigation infrastructure.
