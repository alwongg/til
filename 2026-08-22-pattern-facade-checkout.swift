# Pattern: Put checkout complexity behind a facade

When a feature needs inventory, payment, and receipt services, I avoid making the view model coordinate all three. A facade gives the caller one business-level operation and keeps the ordering rules in one place.

```swift
import Foundation

struct Order: Sendable { let id: UUID; let total: Decimal }

protocol InventoryChecking: Sendable {
    func reserve(order: Order) async throws
}
protocol Charging: Sendable {
    func charge(order: Order) async throws -> String
}
protocol ReceiptSending: Sendable {
    func send(order: Order, paymentID: String) async throws
}

struct CheckoutFacade: Sendable {
    let inventory: any InventoryChecking
    let payments: any Charging
    let receipts: any ReceiptSending

    func complete(_ order: Order) async throws -> String {
        // Reserve before charging so payment never succeeds for unavailable stock.
        try await inventory.reserve(order: order)
        let paymentID = try await payments.charge(order: order)
        try await receipts.send(order: order, paymentID: paymentID)
        return paymentID
    }
}
```

The facade is not a dumping ground: it owns a small, coherent workflow. I keep service-specific APIs out of UI code, inject the facade as a dependency, and add compensation (such as releasing a reservation) when the workflow requires it.
