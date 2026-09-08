/*
# Coordinator Pattern: Keep Navigation Out of SwiftUI Views

When a SwiftUI feature owns its own routing, the view starts deciding both *what to render* and *where the user goes next*. I keep that decision in a coordinator so navigation remains testable and the feature view stays focused on state.

The coordinator owns the route enum and turns intents into navigation state. The view model calls semantic actions (`showOrder`, `dismiss`) instead of reaching for `NavigationPath` directly.

Production note: inject the coordinator behind a protocol when a flow crosses feature boundaries. For a small, local flow, an `@Observable` coordinator is enough.
*/

import Foundation
import Observation

@MainActor
@Observable
final class OrdersCoordinator {
    enum Route: Hashable {
        case orderDetail(id: UUID)
        case support
    }

    var path: [Route] = []
    var presentedRoute: Route?

    func showOrder(id: UUID) {
        // The feature describes intent; it does not know navigation mechanics.
        path.append(.orderDetail(id: id))
    }

    func showSupport() {
        presentedRoute = .support
    }

    func dismissSheet() {
        presentedRoute = nil
    }
}

@MainActor
final class OrdersViewModel {
    private let coordinator: OrdersCoordinator

    init(coordinator: OrdersCoordinator) {
        self.coordinator = coordinator
    }

    func didTapOrder(_ id: UUID) {
        coordinator.showOrder(id: id)
    }
}
