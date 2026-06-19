import Foundation

// Strategy Pattern
// I reach for Strategy when a feature needs interchangeable business rules
// without turning the view model into a switch statement graveyard.

struct CartItem {
    let price: Decimal
    let quantity: Int
}

protocol DiscountStrategy {
    var name: String { get }
    func discountedTotal(for items: [CartItem]) -> Decimal
}

struct RegularPricing: DiscountStrategy {
    let name = "regular"

    func discountedTotal(for items: [CartItem]) -> Decimal {
        items.reduce(0) { $0 + ($1.price * Decimal($1.quantity)) }
    }
}

struct MemberPricing: DiscountStrategy {
    let name = "member"

    func discountedTotal(for items: [CartItem]) -> Decimal {
        let subtotal = items.reduce(0) { $0 + ($1.price * Decimal($1.quantity)) }
        return subtotal * 0.9
    }
}

struct CheckoutService {
    private let strategy: DiscountStrategy

    init(strategy: DiscountStrategy) {
        self.strategy = strategy
    }

    func total(for items: [CartItem]) -> Decimal {
        strategy.discountedTotal(for: items)
    }
}

// In production, I inject the strategy from feature flags, account state,
// or an experiment bucket so pricing rules stay isolated and testable.
