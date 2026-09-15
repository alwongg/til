// Architecture Pattern: A Checkout Facade
//
// I use a facade when a screen needs one intention — “place this order” — but
// the implementation crosses inventory, payment, and receipt services. The
// view model depends on this small API instead of learning service order.

import Foundation

struct Order: Sendable {
    let id: UUID
    let amount: Decimal
}

protocol InventoryChecking { func reserve(_ order: Order) async throws }
protocol Charging { func charge(_ amount: Decimal) async throws }
protocol ReceiptSending { func send(for order: Order) async throws }

enum CheckoutError: Error { case unavailable }

struct CheckoutFacade {
    let inventory: any InventoryChecking
    let payments: any Charging
    let receipts: any ReceiptSending

    func place(_ order: Order) async throws {
        // Reserving first prevents charging for stock we cannot fulfil.
        try await inventory.reserve(order)
        try await payments.charge(order.amount)
        try await receipts.send(for: order)
    }
}

// My ViewModel only calls `checkout.place(order)`. I keep compensation
// (refund/release) in this boundary too once the workflow needs it.
