// Architecture Pattern: Facade for Checkout
//
// I use a facade when a feature needs several services but the caller should
// express one intent. The view model owns checkout, not payment orchestration.

import Foundation

struct Order: Sendable {
    let id: UUID
    let total: Decimal
}

protocol InventoryChecking {
    func reserve(_ order: Order) async throws
}

protocol Charging {
    func charge(amount: Decimal) async throws
}

protocol ReceiptSending {
    func send(for order: Order) async throws
}

struct CheckoutFacade {
    private let inventory: any InventoryChecking
    private let payments: any Charging
    private let receipts: any ReceiptSending

    init(inventory: any InventoryChecking, payments: any Charging, receipts: any ReceiptSending) {
        self.inventory = inventory
        self.payments = payments
        self.receipts = receipts
    }

    func complete(_ order: Order) async throws {
        try await inventory.reserve(order)
        try await payments.charge(amount: order.total)
        try await receipts.send(for: order)
    }
}

// The facade is the policy boundary. I can add compensation, analytics, or
// idempotency here without leaking those decisions into every call site.
