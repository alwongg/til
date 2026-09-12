// Coordinator Pattern: keep navigation out of feature views
//
// I use a coordinator when a flow crosses multiple screens. The view emits intent;
// the coordinator owns route construction, so navigation decisions remain testable.

import Foundation

struct Profile: Hashable, Sendable {
    let id: UUID
    let name: String
}

enum ProfileRoute: Hashable {
    case details(Profile)
    case edit(Profile)
}

@MainActor
final class ProfileCoordinator {
    private(set) var path: [ProfileRoute] = []

    func showDetails(for profile: Profile) {
        path.append(.details(profile))
    }

    func edit(_ profile: Profile) {
        path.append(.edit(profile))
    }

    func finishFlow() {
        // Popping the entire flow prevents child screens from deciding their own exit.
        path.removeAll()
    }
}

// In SwiftUI, inject this coordinator into the feature root and bind
// NavigationStack(path:) to coordinator.path. Child views call closures such as
// onEdit(profile), keeping them unaware of the app's navigation structure.
