# Strategy Pattern: Shipping Rules Without Checkout Conditionals

I use a strategy when a business rule has multiple valid implementations and the caller should not know which one it received. Shipping quotes are a good example: checkout selects a rule once, then asks it for a quote. Adding same-day delivery becomes a new type—not another branch threaded through the view model.

```swift
import Foundation

struct Cart { let subtotal: Decimal; let postalCode: String }

protocol ShippingStrategy {
    func quote(for cart: Cart) -> Decimal
}

struct StandardShipping: ShippingStrategy {
    func quote(for cart: Cart) -> Decimal {
        cart.subtotal >= 50 ? 0 : 8
    }
}

struct ExpressShipping: ShippingStrategy {
    func quote(for cart: Cart) -> Decimal { 18 }
}

struct CheckoutService {
    private let shipping: any ShippingStrategy

    init(shipping: any ShippingStrategy) {
        self.shipping = shipping // Selection belongs at composition time.
    }

    func total(for cart: Cart) -> Decimal {
        cart.subtotal + shipping.quote(for: cart)
    }
}
```

The important boundary is selection versus execution. I select `StandardShipping` or `ExpressShipping` in a composition root based on the customer’s choice and eligibility. `CheckoutService` only executes the chosen policy, which keeps it easy to test with a fixed or spy strategy.

I avoid a strategy type when variants are tiny and stable; a `switch` is clearer then. I introduce this pattern when policy changes independently, needs isolated tests, or is likely to gain new cases.
