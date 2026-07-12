import Foundation

// I use a coordinator when navigation rules start leaking into view models.
// The payoff is simple: views describe intent, coordinators own flow.
protocol Coordinator {
    associatedtype Route
    func start()
    func handle(_ route: Route)
}

enum AppRoute: Hashable {
    case home
    case detail(id: UUID)
    case settings
}

@MainActor
final class AppCoordinator: Coordinator {
    private(set) var path: [AppRoute] = []

    func start() {
        path = [.home]
    }

    func handle(_ route: AppRoute) {
        switch route {
        case .home:
            path = [.home]
        case .detail(let id):
            // Route payloads stay explicit, which makes deep links easier to test.
            path.append(.detail(id: id))
        case .settings:
            path.append(.settings)
        }
    }
}

@MainActor
final class HomeViewModel {
    private let coordinator: AppCoordinator

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    func didTapSettings() {
        coordinator.handle(.settings)
    }

    func didSelectItem(id: UUID) {
        coordinator.handle(.detail(id: id))
    }
}
