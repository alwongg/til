import Foundation

// I keep the policy behind a protocol so checkout never needs a growing switch.
protocol ShippingStrategy {
    func quote(for subtotal: Decimal) -> Decimal
}

struct FlatRateShipping: ShippingStrategy {
    let fee: Decimal
    func quote(for subtotal: Decimal) -> Decimal { fee }
}

struct FreeOverThresholdShipping: ShippingStrategy {
    let threshold: Decimal
    let otherwise: Decimal

    func quote(for subtotal: Decimal) -> Decimal {
        subtotal >= threshold ? 0 : otherwise
    }
}

struct Checkout {
    private let shipping: any ShippingStrategy

    init(shipping: any ShippingStrategy) {
        self.shipping = shipping
    }

    func total(for subtotal: Decimal) -> Decimal {
        subtotal + shipping.quote(for: subtotal)
    }
}

@main
struct Demo {
    static func main() {
        let checkout = Checkout(
            shipping: FreeOverThresholdShipping(threshold: 50, otherwise: 8)
        )
        print(checkout.total(for: 42)) // 50
    }
}
