// Architecture Pattern: Coordinator Navigation
//
// I keep navigation decisions out of feature screens. A coordinator owns flow,
// while views report intent through a small protocol. That makes deep links and
// flow tests independent of a concrete navigation controller.

import Foundation

enum ProfileRoute: Equatable {
    case details(userID: UUID)
    case edit(userID: UUID)
}

protocol ProfileRouting: AnyObject {
    func showDetails(for userID: UUID)
    func showEditor(for userID: UUID)
}

final class ProfileCoordinator: ProfileRouting {
    private(set) var routeHistory: [ProfileRoute] = []

    func showDetails(for userID: UUID) {
        // Recording a route here also gives my deep-link handler one entry point.
        routeHistory.append(.details(userID: userID))
    }

    func showEditor(for userID: UUID) {
        routeHistory.append(.edit(userID: userID))
    }
}

final class ProfileViewModel {
    private let router: ProfileRouting

    init(router: ProfileRouting) {
        self.router = router
    }

    func didTapProfile(id: UUID) { router.showDetails(for: id) }
    func didTapEdit(id: UUID) { router.showEditor(for: id) }
}

// I inject ProfileRouting in production and tests, so the view model never
// depends on UIKit, SwiftUI NavigationPath, or a concrete screen stack.
