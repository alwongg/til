// Facade Pattern: make a multi-service checkout read like one operation
//
// In a feature module, I keep orchestration behind a facade so the ViewModel
// owns intent, not the ordering rules of payment, inventory, and receipts.

import Foundation

struct Order: Sendable {
    let id: UUID
    let total: Decimal
}

protocol PaymentCharging { func charge(amount: Decimal) async throws }
protocol InventoryReserving { func reserve(orderID: UUID) async throws }
protocol ReceiptSending { func send(for order: Order) async throws }

enum CheckoutError: Error { case paymentFailed }

struct CheckoutFacade {
    let payment: PaymentCharging
    let inventory: InventoryReserving
    let receipts: ReceiptSending

    func complete(_ order: Order) async throws {
        // Reserve first: failing before charging avoids an unnecessary refund path.
        try await inventory.reserve(orderID: order.id)
        try await payment.charge(amount: order.total)
        try await receipts.send(for: order)
    }
}

// My ViewModel depends on CheckoutFacade rather than three infrastructure APIs.
// That boundary makes the happy path testable with three small fakes, while
// retries, compensation, and analytics stay centralized as checkout evolves.
