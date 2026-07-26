# Architecture reflection: boundaries are product decisions

I used to treat architecture as an internal cleanup project: split types, add protocols, move code into layers. That framing misses the point. A boundary is worth introducing when it preserves a product decision I expect to change.

## The legacy shape: policy hidden in a screen

```swift
@MainActor
final class CheckoutViewModel: ObservableObject {
    func submit(cart: Cart) async throws {
        let total = cart.items.reduce(0) { $0 + $1.price }
        if total > 100 { // discount policy is buried in UI flow
            // apply discount
        }
        try await URLSession.shared.data(for: request)
    }
}
```

This works until checkout rules vary by region, experiment, membership, or backend capability. Then a UI-oriented type becomes the place every team edits, tests, and argues about.

## The modern shape: name the changing decision

```swift
protocol DiscountPolicy: Sendable {
    func discount(for cart: Cart) -> Decimal
}

struct MemberDiscountPolicy: DiscountPolicy {
    func discount(for cart: Cart) -> Decimal {
        cart.isMember ? Decimal(10) : 0
    }
}

struct CheckoutUseCase: Sendable {
    let discountPolicy: any DiscountPolicy
    let orders: any OrderRepository

    func submit(_ cart: Cart) async throws {
        let discount = discountPolicy.discount(for: cart)
        try await orders.place(cart: cart, discount: discount)
    }
}
```

The protocol is not “clean architecture theatre.” It gives the discount rule a stable home and leaves the screen responsible for presentation. I can change the rule, test it in isolation, or select it at composition time without rewriting checkout UI.

## Migration strategy

1. Trace the next likely change, not every possible abstraction.
2. Extract that decision behind a small domain-shaped interface.
3. Keep the existing caller and inject the new collaborator there.
4. Move behavior with characterization tests before deleting the old branch.
5. Stop once the change has one obvious owner.

## Production notes

- A protocol should represent a real seam: a changing policy, an external system, or a testable side effect.
- Keep data flow directional. View models call use cases; use cases depend on repository interfaces; infrastructure implements them.
- Prefer composition at the app or feature boundary over a global service locator.
- If a boundary has only one implementation forever and no anticipated variation, leave it concrete. Indirection has a maintenance cost too.

My practical test: when product asks “can this rule work differently next quarter?”, I should be able to point to one type that owns the answer.
