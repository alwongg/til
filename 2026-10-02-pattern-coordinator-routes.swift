import Foundation

// A coordinator owns navigation so view controllers only render and forward intent.
protocol CheckoutCoordinating: AnyObject {
    func showPayment(orderID: UUID)
    func showConfirmation(orderID: UUID)
}

final class CheckoutCoordinator: CheckoutCoordinating {
    private var presentedOrderID: UUID?

    func showPayment(orderID: UUID) {
        presentedOrderID = orderID
        // In UIKit, push PaymentViewController here. Keep the route decision out of the view.
        print("Route to payment for \(orderID)")
    }

    func showConfirmation(orderID: UUID) {
        guard presentedOrderID == orderID else { return }
        // The coordinator is the only place that knows this transition is valid.
        print("Route to confirmation for \(orderID)")
    }
}

final class CheckoutViewModel {
    private let coordinator: CheckoutCoordinating
    private let orderID: UUID

    init(orderID: UUID, coordinator: CheckoutCoordinating) {
        self.orderID = orderID
        self.coordinator = coordinator
    }

    func payTapped() { coordinator.showPayment(orderID: orderID) }
    func paymentSucceeded() { coordinator.showConfirmation(orderID: orderID) }
}
