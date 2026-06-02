import Foundation

/*
 Coordinator Pattern

 I use a coordinator when I want navigation decisions to live outside the screen.
 The view model stays focused on state and intent, while the coordinator owns flow.
*/

protocol AppRouting: AnyObject {
    func showLogin()
    func showHome(userID: UUID)
}

final class AppCoordinator: AppRouting {
    func showLogin() {
        print("Present login screen")
    }

    func showHome(userID: UUID) {
        print("Push home for \(userID)")
    }
}

final class SessionViewModel {
    private weak var router: AppRouting?

    init(router: AppRouting) {
        self.router = router
    }

    func handleLaunch(hasToken: Bool, userID: UUID?) {
        guard hasToken, let userID else {
            router?.showLogin()
            return
        }

        // The view model decides intent; the coordinator decides navigation.
        router?.showHome(userID: userID)
    }
}

let coordinator = AppCoordinator()
let viewModel = SessionViewModel(router: coordinator)
viewModel.handleLaunch(hasToken: true, userID: UUID())
