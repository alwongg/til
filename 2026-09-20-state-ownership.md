# Architecture Thinking: Make State Ownership Obvious

I treat most SwiftUI bugs as ownership bugs before I treat them as rendering bugs. When a screen becomes unpredictable, the usual cause is not that SwiftUI failed to redraw; it is that two layers both believe they own the same decision.

## Legacy approach: pass bindings until the screen works

My old move was to thread `@Binding` through child views because it was fast:

```swift
struct CheckoutView: View {
    @State private var isShowingReceipt = false

    var body: some View {
        CartView(isShowingReceipt: $isShowingReceipt)
    }
}

struct CartView: View {
    @Binding var isShowingReceipt: Bool

    var body: some View {
        Button("Place order") {
            isShowingReceipt = true
        }
    }
}
```

This is fine for a local display concern. It breaks down when `CartView` also starts deciding validation, submitting an order, handling an error, and navigating. The child now knows too much about the parent’s flow, and a new path (deep link, retry, analytics experiment) creates another place that can mutate the same state.

## Modern approach: one owner, explicit intents

I keep mutable flow state at the feature boundary, then let children emit narrow intents:

```swift
@MainActor
final class CheckoutViewModel: ObservableObject {
    enum Route: Identifiable {
        case receipt(orderID: String)
        var id: String { "\(self)" }
    }

    @Published private(set) var route: Route?
    @Published private(set) var isSubmitting = false

    func placeOrder() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        // The repository owns I/O; this object owns the UI decision.
        let orderID = "order-123"
        route = .receipt(orderID: orderID)
    }
}

struct CartView: View {
    let onPlaceOrder: () -> Void

    var body: some View {
        Button("Place order", action: onPlaceOrder)
    }
}
```

The view model owns submission and routing because those decisions belong to the checkout feature. `CartView` remains reusable: it describes a user action without knowing where the app goes next.

## Migration strategy

1. List every mutable property in the screen and name its owner: view-local, feature view model, or app coordinator.
2. Convert child `Binding`s that change business or navigation state into closures or small action enums.
3. Make asynchronous operations enter through one feature method. Guard duplicate taps there, not in every button.
4. Keep a binding when the child is truly editing parent-owned presentation data—text fields and toggles are good examples.

## Production notes

- `private(set)` makes the legal mutation path visible in code review.
- `defer` prevents a loading state from getting stuck when the async path grows error handling.
- Routing state deserves stable identifiers; enum cases scale better than scattered Boolean flags.
- I do not force every small component through a view model. The goal is clear ownership, not ceremony.

My rule: a view may render state and report intent, but the layer that understands the consequence should own the mutation.
