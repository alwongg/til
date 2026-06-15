/*
Strategy Pattern in Swift

I reach for the strategy pattern when one workflow stays stable but one decision step changes.
A payment flow is a good example: the checkout pipeline is fixed, but pricing rules differ by customer type.
Keeping those rules behind a protocol makes the call site boring and keeps conditionals from spreading.
*/

import Foundation

protocol PricingStrategy {
    func finalPrice(for basePrice: Decimal) -> Decimal
}

struct StandardPricing: PricingStrategy {
    func finalPrice(for basePrice: Decimal) -> Decimal { basePrice }
}

struct MemberPricing: PricingStrategy {
    func finalPrice(for basePrice: Decimal) -> Decimal {
        basePrice * Decimal(string: "0.9")!
    }
}

struct LaunchPromoPricing: PricingStrategy {
    let flatDiscount: Decimal

    func finalPrice(for basePrice: Decimal) -> Decimal {
        max(0, basePrice - flatDiscount)
    }
}

struct CheckoutService {
    private let strategy: PricingStrategy

    init(strategy: PricingStrategy) {
        self.strategy = strategy
    }

    func checkoutTotal(for basePrice: Decimal) -> Decimal {
        strategy.finalPrice(for: basePrice)
    }
}

@main
enum Demo {
    static func main() {
        let totals = [
            CheckoutService(strategy: StandardPricing()).checkoutTotal(for: 100),
            CheckoutService(strategy: MemberPricing()).checkoutTotal(for: 100),
            CheckoutService(strategy: LaunchPromoPricing(flatDiscount: 15)).checkoutTotal(for: 100)
        ]

        print(totals.map { NSDecimalNumber(decimal: $0).stringValue }.joined(separator: ", "))
    }
}
