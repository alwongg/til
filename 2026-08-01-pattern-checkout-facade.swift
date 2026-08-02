// I use a facade when a feature needs a small, intention-revealing API over several services.
// The view model asks for checkout; it does not learn the order of inventory and payment calls.

import Foundation

struct CheckoutReceipt: Sendable {
    let orderID: UUID
    let confirmation: String
}

protocol InventoryChecking: Sendable {
    func reserve(sku: String, quantity: Int) async throws
}

protocol Charging: Sendable {
    func charge(cents: Int) async throws -> String
}

struct CheckoutFacade: Sendable {
    private let inventory: any InventoryChecking
    private let payments: any Charging

    init(inventory: any InventoryChecking, payments: any Charging) {
        self.inventory = inventory
        self.payments = payments
    }

    func checkout(sku: String, quantity: Int, totalCents: Int) async throws -> CheckoutReceipt {
        // Reserving first avoids taking money for stock I cannot fulfill.
        try await inventory.reserve(sku: sku, quantity: quantity)
        let confirmation = try await payments.charge(cents: totalCents)
        return CheckoutReceipt(orderID: UUID(), confirmation: confirmation)
    }
}

struct DemoInventory: InventoryChecking {
    func reserve(sku: String, quantity: Int) async throws {}
}

struct DemoPayments: Charging {
    func charge(cents: Int) async throws -> String { "pay_123" }
}

@main
struct Demo {
    static func main() async throws {
        let checkout = CheckoutFacade(inventory: DemoInventory(), payments: DemoPayments())
        let receipt = try await checkout.checkout(sku: "coffee", quantity: 1, totalCents: 450)
        print(receipt.confirmation)
    }
}
