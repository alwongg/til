// Architecture Pattern: Coordinator Routing
//
// I keep navigation decisions out of SwiftUI views. A view should render state
// and emit an intent; the coordinator owns the route and its dependencies.

import Foundation

enum AppRoute: Hashable {
    case profile(userID: UUID)
    case settings
}

@MainActor
protocol AppCoordinating: AnyObject {
    var path: [AppRoute] { get set }
    func showProfile(for userID: UUID)
    func showSettings()
    func dismiss()
}

@MainActor
final class AppCoordinator: AppCoordinating {
    var path: [AppRoute] = []

    func showProfile(for userID: UUID) {
        // The caller cannot choose implementation details—only a user intent.
        path.append(.profile(userID: userID))
    }

    func showSettings() {
        path.append(.settings)
    }

    func dismiss() {
        _ = path.popLast()
    }
}

@main
struct CoordinatorDemo {
    static func main() async {
        let coordinator = AppCoordinator()
        coordinator.showProfile(for: UUID())
        coordinator.showSettings()
        coordinator.dismiss()
        print(coordinator.path.count)
    }
}
