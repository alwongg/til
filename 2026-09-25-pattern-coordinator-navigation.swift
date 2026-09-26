import Foundation

protocol NavigationDriving: AnyObject {
    func showHome()
    func showOrder(id: String)
    func showSignIn()
}

enum AppRoute {
    case home
    case order(id: String)
    case signedOut
}

@MainActor
final class AppCoordinator {
    private weak var navigator: NavigationDriving?

    init(navigator: NavigationDriving) {
        self.navigator = navigator
    }

    func start() {
        // I keep the launch decision here so views do not learn app-wide routing rules.
        navigate(to: .home)
    }

    func navigate(to route: AppRoute) {
        guard let navigator else { return }

        switch route {
        case .home:
            navigator.showHome()
        case let .order(id):
            navigator.showOrder(id: id)
        case .signedOut:
            navigator.showSignIn()
        }
    }
}

final class RecordingNavigator: NavigationDriving {
    private(set) var events: [String] = []

    func showHome() { events.append("home") }
    func showOrder(id: String) { events.append("order:" + id) }
    func showSignIn() { events.append("signIn") }
}
