import Foundation

/*
 # Architecture Pattern — Coordinator pattern

 I reach for a coordinator when navigation starts leaking out of the app shell and into view models.
 The win is simple: screens stay focused on state and intent, while one object owns the flow.
 */

protocol Coordinator: AnyObject {
    var children: [Coordinator] { get set }
    func start()
}

final class LoginCoordinator: Coordinator {
    var children: [Coordinator] = []
    private let onAuthenticated: () -> Void

    init(onAuthenticated: @escaping () -> Void) {
        self.onAuthenticated = onAuthenticated
    }

    func start() {
        showLogin()
    }

    private func showLogin() {
        // I keep the routing decision here so the feature layer stays testable.
        let credentialsAreValid = true
        if credentialsAreValid {
            onAuthenticated()
        }
    }
}

final class AppCoordinator: Coordinator {
    var children: [Coordinator] = []

    func start() {
        let login = LoginCoordinator { [weak self] in
            self?.showMainExperience()
        }
        children.append(login)
        login.start()
    }

    private func showMainExperience() {
        // The coordinator tears down finished flows instead of leaving orphan state around.
        children.removeAll { $0 is LoginCoordinator }
        print("Present main tab bar")
    }
}

@main
struct DemoApp {
    static func main() {
        let app = AppCoordinator()
        app.start()
    }
}
