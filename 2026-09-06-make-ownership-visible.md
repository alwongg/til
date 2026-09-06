# Architecture thinking: make ownership visible before adding another protocol

When an iOS feature becomes difficult to change, I first ask **who owns the decision**. I do not start by adding a protocol, a coordinator, or another layer.

## The legacy shape

A screen often starts with one view model that fetches data, maps it, decides navigation, saves preferences, and emits analytics. It works until a new requirement touches all five responsibilities. The code is not necessarily large; its ownership is simply hidden.

```swift
final class CheckoutViewModel: ObservableObject {
    func placeOrder() async {
        let order = try? await api.submit(cart)
        analytics.track("order_placed")
        router.showConfirmation(order)
    }
}
```

The problem is not `async`. The problem is that this type owns policy, transport, side effects, and navigation at once.

## The modern shape

I make each decision point explicit:

- A **use case** owns the business outcome: placing an order.
- A **repository** owns where order data comes from.
- The **view model** owns presentation state and user intent.
- A **coordinator** owns navigation transitions.
- An **analytics client** observes the completed outcome; it does not steer it.

```swift
@MainActor
final class CheckoutViewModel: ObservableObject {
    private let placeOrder: PlaceOrder
    private let onCompleted: (Order) -> Void

    func submit(cart: Cart) async {
        do {
            let order = try await placeOrder.execute(cart: cart)
            onCompleted(order)
        } catch {
            // Map domain failure into UI state here.
        }
    }
}
```

This is not architecture for architecture's sake. It gives me a reliable answer to “where should this new rule live?”

## Migration strategy

1. Name the decision currently buried in the view model.
2. Extract one use case behind a concrete type first; I only introduce a protocol when substitution or testing needs it.
3. Keep the old call site and move behavior incrementally.
4. Add a focused test for the rule before extracting the next responsibility.

## Production notes

I avoid turning every noun into a layer. A feature earns a boundary when it has an independent reason to change, an external dependency, or a rule worth testing in isolation. The goal is not maximum separation. The goal is making future changes local, legible, and safe.
