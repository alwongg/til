# Architecture Reflection: Make Dependencies Visible Before They Become Policy

When an iOS feature starts simple, I often treat dependencies as implementation details: a view model reaches for `URLSession`, `UserDefaults`, analytics, and a clock directly. That is fast at first. The cost appears later, when tests become setup-heavy and a product decision is hidden inside a default value.

## Legacy approach: dependencies discovered at runtime

```swift
final class CheckoutViewModel: ObservableObject {
    @Published private(set) var state: State = .idle

    func submit(order: Order) async {
        let request = URLRequest.checkout(order)
        let (data, _) = try! await URLSession.shared.data(for: request)
        UserDefaults.standard.set(Date(), forKey: "lastCheckout")
        Analytics.shared.track("checkout_completed")
        state = .success(try! JSONDecoder().decode(Receipt.self, from: data))
    }
}
```

This is not just hard to test. It couples the feature to policy: which session is used, how dates are produced, whether analytics is required for success, and where persistence belongs.

## Modern approach: a small dependency boundary

```swift
struct CheckoutDependencies {
    let submitOrder: @Sendable (Order) async throws -> Receipt
    let now: @Sendable () -> Date
    let recordCompletion: @Sendable (Date) -> Void
    let track: @Sendable (String) -> Void
}

@MainActor
final class CheckoutViewModel: ObservableObject {
    @Published private(set) var state: State = .idle
    private let dependencies: CheckoutDependencies

    init(dependencies: CheckoutDependencies) {
        self.dependencies = dependencies
    }

    func submit(order: Order) async {
        state = .loading
        do {
            let receipt = try await dependencies.submitOrder(order)
            let completedAt = dependencies.now()
            dependencies.recordCompletion(completedAt)
            dependencies.track("checkout_completed")
            state = .success(receipt)
        } catch {
            state = .failure(error.localizedDescription)
        }
    }
}
```

I keep the boundary focused on the feature's decisions, not on every framework type. The view model can now be exercised with deterministic closures, while the composition root owns the concrete `URLSession`, storage, and analytics wiring.

## Migration strategy

1. Extract one side effect at a time, starting with the one that blocks tests.
2. Introduce a feature-specific dependency struct instead of a global service locator.
3. Build the live dependencies in the app composition root.
4. Add a test factory with recording closures and controlled results.
5. Only generalize a dependency after two features genuinely share the same policy.

## Production notes

- Injecting a `now` closure prevents date-sensitive tests from becoming flaky.
- Keep analytics best-effort unless product requirements say it must affect the user flow.
- Use `@MainActor` for UI state and make network work explicit through async dependencies.
- Dependency injection is not an end in itself. The goal is to make product policy visible, replaceable, and testable.

My rule: if changing a dependency would change a product decision, I want that dependency visible at the feature boundary.
