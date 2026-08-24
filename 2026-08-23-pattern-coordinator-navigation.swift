// Architecture Pattern: Keep Navigation Ownership in a Coordinator
//
// I reach for a coordinator when a view controller starts knowing too much about
// app flow. The controller should emit intent; the coordinator owns the decision
// and retains any child flow for exactly as long as that flow is alive.

import Foundation

enum AppRoute {
    case product(id: UUID)
    case checkout
}

protocol Routing: AnyObject {
    func handle(_ route: AppRoute)
}

final class AppCoordinator: Routing {
    private var checkoutCoordinator: CheckoutCoordinator?

    func start() {
        showHome()
    }

    func handle(_ route: AppRoute) {
        switch route {
        case let .product(id):
            showProduct(id: id)
        case .checkout:
            let child = CheckoutCoordinator(onFinish: { [weak self] in
                self?.checkoutCoordinator = nil // Release the child flow deterministically.
            })
            checkoutCoordinator = child
            child.start()
        }
    }

    private func showHome() { print("Show home") }
    private func showProduct(id: UUID) { print("Show product: \(id)") }
}

final class CheckoutCoordinator {
    private let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }
    func start() { print("Start checkout") }
    func finish() { onFinish() }
}

@main
struct Demo {
    static func main() {
        let app = AppCoordinator()
        app.start()
        app.handle(.product(id: UUID()))
        app.handle(.checkout)
    }
}
