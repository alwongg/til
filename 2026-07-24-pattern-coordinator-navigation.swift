import Foundation

// Architecture Pattern: Coordinator
// I keep navigation decisions outside view controllers so a screen owns rendering,
// while the coordinator owns the journey and remains easy to exercise in tests.

enum AppRoute: Equatable {
    case home
    case orderDetail(id: UUID)
}

protocol Navigating: AnyObject {
    func show(_ route: AppRoute)
}

@MainActor
final class AppCoordinator {
    private let navigator: Navigating

    init(navigator: Navigating) {
        self.navigator = navigator
    }

    func start() {
        navigator.show(.home)
    }

    func openOrder(id: UUID) {
        // This policy stays at the app-flow boundary, not in a view controller.
        navigator.show(.orderDetail(id: id))
    }
}

final class RecordingNavigator: Navigating {
    private(set) var routes: [AppRoute] = []

    func show(_ route: AppRoute) {
        routes.append(route)
    }
}
