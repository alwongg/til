// 2026-08-13 — Coordinator Pattern
//
// I keep navigation policy out of screens. A coordinator owns the flow,
// while a screen exposes user intent through a closure. That lets me test the
// transition policy without constructing a UI hierarchy.

import Foundation

protocol ProfileRouting: AnyObject {
    func showSettings()
}

final class ProfileScreen {
    weak var router: ProfileRouting?

    func didTapSettings() {
        router?.showSettings()
    }
}

final class AppNavigator {
    private(set) var routeHistory: [String] = []

    func push(_ route: String) {
        routeHistory.append(route)
    }
}

final class ProfileCoordinator: ProfileRouting {
    private let navigator: AppNavigator
    private let screen: ProfileScreen

    init(navigator: AppNavigator, screen: ProfileScreen = ProfileScreen()) {
        self.navigator = navigator
        self.screen = screen
        screen.router = self
    }

    func start() -> ProfileScreen {
        navigator.push("profile")
        return screen
    }

    func showSettings() {
        // The coordinator—not ProfileScreen—chooses the destination.
        navigator.push("settings")
    }
}

/*
In UIKit, AppNavigator can wrap UINavigationController and ProfileScreen can
be a view controller. I add this boundary when a feature has several routes,
flow-level dependencies, or navigation tests; for one local modal, it is
usually needless ceremony.
*/
