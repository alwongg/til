// Architecture Pattern: Coordinator as an Explicit Navigation Boundary
//
// I keep navigation decisions outside feature screens. That makes a screen
// reusable, testable, and unable to quietly grow into an app-wide router.

import Foundation

protocol Coordinating: AnyObject {
    func start()
}

final class AppCoordinator: Coordinating {
    enum Route: Hashable {
        case home
        case profile(userID: UUID)
        case settings
    }

    private var handlers: [Route: () -> Void] = [:]

    func register(_ route: Route, handler: @escaping () -> Void) {
        // Registration keeps framework-specific presentation at the composition root.
        handlers[route] = handler
    }

    func navigate(to route: Route) {
        guard let handler = handlers[route] else {
            assertionFailure("Missing route handler: \(route)")
            return
        }
        handler()
    }

    func start() {
        navigate(to: .home)
    }
}

// A feature emits intent; it never needs to know UIKit, SwiftUI, or another feature.
final class ProfileViewModel {
    var onOpenSettings: (() -> Void)?

    func settingsTapped() {
        onOpenSettings?()
    }
}
