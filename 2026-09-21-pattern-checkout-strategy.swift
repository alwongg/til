// Strategy Pattern: Make Checkout Policy Replaceable
//
// I use Strategy when a workflow stays stable but one decision varies by
// market, experiment, or account. The checkout coordinator owns the flow;
// policies own the rule. That keeps conditionals from spreading through UI.

import Foundation

struct Cart: Sendable {
    let subtotal: Decimal
    let isMember: Bool
}

protocol DiscountStrategy: Sendable {
    func discount(for cart: Cart) -> Decimal
}

struct NoDiscount: DiscountStrategy {
    func discount(for cart: Cart) -> Decimal { 0 }
}

struct MemberDiscount: DiscountStrategy {
    func discount(for cart: Cart) -> Decimal {
        guard cart.isMember else { return 0 }
        return cart.subtotal * Decimal(string: "0.10")!
    }
}

struct CheckoutService {
    private let discount: any DiscountStrategy

    init(discount: any DiscountStrategy) {
        self.discount = discount
    }

    func total(for cart: Cart) -> Decimal {
        // The stable flow depends on an abstraction, so I can add a campaign
        // without editing every caller or coupling the UI to business policy.
        max(0, cart.subtotal - discount.discount(for: cart))
    }
}
