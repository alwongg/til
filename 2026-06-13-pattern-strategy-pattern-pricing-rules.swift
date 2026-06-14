import Foundation

protocol DiscountStrategy {
    func finalPrice(for subtotal: Decimal) -> Decimal
}

struct NoDiscount: DiscountStrategy {
    func finalPrice(for subtotal: Decimal) -> Decimal { subtotal }
}

struct PercentageDiscount: DiscountStrategy {
    let rate: Decimal

    func finalPrice(for subtotal: Decimal) -> Decimal {
        subtotal - (subtotal * rate)
    }
}

struct CartPricer {
    private let strategy: DiscountStrategy

    init(strategy: DiscountStrategy) {
        self.strategy = strategy
    }

    func total(for subtotal: Decimal) -> Decimal {
        // I like this because pricing rules change often, while the checkout flow stays stable.
        strategy.finalPrice(for: subtotal)
    }
}

@main
struct Demo {
    static func main() {
        let subtotal = Decimal(120)
        let vipPricer = CartPricer(strategy: PercentageDiscount(rate: 0.15))
        let fallbackPricer = CartPricer(strategy: NoDiscount())

        print("VIP total: \(vipPricer.total(for: subtotal))")
        print("Fallback total: \(fallbackPricer.total(for: subtotal))")
    }
}
