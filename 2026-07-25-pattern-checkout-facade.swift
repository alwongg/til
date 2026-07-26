// Facade Pattern — one boundary for a checkout workflow
//
// I use a facade when a caller needs one business action but the work spans
// several subsystems. The view model should ask for `placeOrder`, not learn
// payment, inventory, and receipt sequencing.

import Foundation

struct Order: Sendable {
    let id: UUID
    let totalCents: Int
}

enum CheckoutError: Error {
    case outOfStock
    case paymentDeclined
}

protocol InventoryChecking: Sendable {
    func reserve(order: Order) async throws
}

protocol Charging: Sendable {
    func charge(cents: Int) async throws
}

protocol ReceiptSending: Sendable {
    func send(for order: Order) async
}

struct CheckoutFacade: Sendable {
    let inventory: any InventoryChecking
    let payments: any Charging
    let receipts: any ReceiptSending

    func placeOrder(_ order: Order) async throws {
        // I reserve first so a declined card does not create an irreversible charge.
        try await inventory.reserve(order: order)
        try await payments.charge(cents: order.totalCents)
        await receipts.send(for: order)
    }
}

// My view model depends on this focused capability; infrastructure stays behind it.
protocol CheckoutPlacing: Sendable {
    func placeOrder(_ order: Order) async throws
}

extension CheckoutFacade: CheckoutPlacing {}
