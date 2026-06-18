import Foundation

// I use a coordinator when navigation starts branching across screens.
// The feature asks for intent; the coordinator decides concrete routes.

enum AppRoute: Hashable {
    case home
    case profile(User.ID)
    case settings
    case onboarding
}

struct User {
    struct ID: Hashable {
        let rawValue: UUID
    }
}

@MainActor
protocol AppNavigating: AnyObject {
    func showHome()
    func showProfile(for userID: User.ID)
    func showSettings()
    func showOnboarding()
}

@MainActor
final class AppCoordinator: AppNavigating {
    private(set) var path: [AppRoute] = [.home]

    func showHome() { path = [.home] }
    func showProfile(for userID: User.ID) { path.append(.profile(userID)) }
    func showSettings() { path.append(.settings) }
    func showOnboarding() { path = [.onboarding] }
}

@MainActor
final class ProfileViewModel {
    private let navigator: AppNavigating
    private let userID: User.ID

    init(userID: User.ID, navigator: AppNavigating) {
        self.userID = userID
        self.navigator = navigator
    }

    func didTapSettings() {
        navigator.showSettings()
    }

    func didSignOut() {
        // I reset the flow in one place instead of sprinkling route logic across views.
        navigator.showOnboarding()
    }
}
