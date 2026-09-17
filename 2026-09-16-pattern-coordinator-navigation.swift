// Coordinator Pattern: make navigation a dependency, not a ViewModel side effect
//
// I keep navigation decisions out of ViewModels. The ViewModel emits an intent;
// its coordinator translates that intent into a route. That boundary makes the
// ViewModel testable without SwiftUI or a navigation stack.

import Foundation

enum AccountRoute: Equatable {
    case profile(userID: String)
    case settings
}

protocol AccountCoordinating: AnyObject {
    func showProfile(userID: String)
    func showSettings()
}

final class AccountViewModel {
    private weak var coordinator: (any AccountCoordinating)?

    init(coordinator: any AccountCoordinating) {
        self.coordinator = coordinator
    }

    func didTapProfile(userID: String) {
        // The ViewModel owns the user intent, not the presentation mechanism.
        coordinator?.showProfile(userID: userID)
    }

    func didTapSettings() {
        coordinator?.showSettings()
    }
}

final class AccountCoordinator: AccountCoordinating {
    private(set) var route: AccountRoute?

    func showProfile(userID: String) {
        route = .profile(userID: userID)
    }

    func showSettings() {
        route = .settings
    }
}

// Production note: a SwiftUI root can observe `route` and map it to a
// NavigationPath. I keep that mapping at the UI edge, so navigation changes
// never force feature ViewModel tests to import SwiftUI.
