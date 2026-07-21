// I use a facade when a feature needs several collaborators but callers should have one intent-revealing entry point.
import Foundation

struct CheckoutRequest {
    let cartID: String
    let paymentToken: String
}

protocol InventoryChecking { func reserve(cartID: String) throws }
protocol Charging { func charge(token: String) throws -> String }
protocol ReceiptSending { func send(orderID: String) }

enum CheckoutError: Error { case emptyCart }

final class CheckoutFacade {
    private let inventory: InventoryChecking
    private let payments: Charging
    private let receipts: ReceiptSending

    init(inventory: InventoryChecking, payments: Charging, receipts: ReceiptSending) {
        self.inventory = inventory
        self.payments = payments
        self.receipts = receipts
    }

    func complete(_ request: CheckoutRequest) throws -> String {
        guard !request.cartID.isEmpty else { throw CheckoutError.emptyCart }
        try inventory.reserve(cartID: request.cartID)
        let orderID = try payments.charge(token: request.paymentToken)
        receipts.send(orderID: orderID)
        return orderID
    }
}

// The facade keeps UI code focused on `complete`; retry, rollback, and analytics
// can evolve behind this boundary without leaking service choreography into views.
