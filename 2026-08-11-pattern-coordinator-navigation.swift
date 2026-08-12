// Architecture Pattern: Coordinator-owned navigation
//
// I keep navigation decisions out of views so a feature can be exercised
// without constructing SwiftUI or UIKit. The coordinator owns transitions;
// screens emit intents.

import Foundation

enum ProfileRoute: Equatable {
    case details(userID: UUID)
    case edit(userID: UUID)
}

protocol ProfileRouting: AnyObject {
    func showDetails(for userID: UUID)
    func showEditor(for userID: UUID)
    func dismiss()
}

final class ProfileCoordinator: ProfileRouting {
    private(set) var path: [ProfileRoute] = []

    func showDetails(for userID: UUID) {
        path.append(.details(userID: userID))
    }

    func showEditor(for userID: UUID) {
        // A coordinator is the single place that decides which transition
        // follows an intent; the screen remains unaware of navigation shape.
        path.append(.edit(userID: userID))
    }

    func dismiss() {
        _ = path.popLast()
    }
}

final class ProfileViewModel {
    private let router: ProfileRouting
    private let userID: UUID

    init(userID: UUID, router: ProfileRouting) {
        self.userID = userID
        self.router = router
    }

    func editTapped() {
        router.showEditor(for: userID)
    }
}
