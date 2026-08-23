# Design Architecture for Deletion, Not Just Addition

When I add a feature, I now ask a less flattering question than “where does this code live?”: **what will I delete when the experiment ends?**

That question has changed how I draw boundaries in iOS apps. The risky architecture is not necessarily messy on day one; it is the one that makes a temporary decision become permanent because removal touches every layer.

## The legacy approach: wire the feature everywhere

A feature flag often starts small, then leaks:

- a `Bool` in `UserDefaults`
- `if` checks in views and view models
- alternate request paths in the API client
- analytics branches beside unrelated events

The feature is easy to add, but deleting it requires remembering every branch. That is how abandoned experiments become accidental product policy.

## The modern approach: make the decision a dependency

I keep the variation behind one protocol and inject the chosen implementation at the composition root:

```swift
import Foundation

protocol CheckoutExperience {
    func destination(for cartID: UUID) -> URL
}

struct ClassicCheckout: CheckoutExperience {
    func destination(for cartID: UUID) -> URL {
        URL(string: "myapp://checkout/\(cartID.uuidString)")!
    }
}

struct ExpressCheckout: CheckoutExperience {
    func destination(for cartID: UUID) -> URL {
        URL(string: "myapp://express-checkout/\(cartID.uuidString)")!
    }
}

@MainActor
final class CheckoutViewModel {
    private let experience: CheckoutExperience

    init(experience: CheckoutExperience) {
        self.experience = experience
    }

    func checkoutURL(for cartID: UUID) -> URL {
        experience.destination(for: cartID)
    }
}
```

The screen does not know about an experiment. It asks for a checkout destination. The app boundary decides whether that is `ClassicCheckout` or `ExpressCheckout`.

## My migration strategy

1. **Name the stable capability**, not the temporary treatment. `CheckoutExperience` survives after the test; `ExpressCheckoutExperiment` does not.
2. **Move branches inward before moving code outward.** First centralize the decision behind a protocol or small function. Then replace call sites.
3. **Inject at the composition root.** SwiftUI’s `App`, a coordinator, or a dependency container owns rollout configuration—not leaf views.
4. **Set a deletion condition.** I add the owner, decision date, and removal path to the experiment ticket before rollout.

## Production notes

- Keep the protocol narrow. A giant “feature service” just relocates coupling.
- Track exposure and outcome analytics beside the composition decision, so both variants report the same event contract.
- Test each implementation directly and test the composition root selects the intended one.
- Once the decision is final, delete the losing implementation and its configuration in the same PR. Leaving a dormant flag is not risk-free; it is deferred complexity.

The point is not to abstract every `if`. I use this boundary when a decision has a meaningful lifetime, rollout, or ownership question. Good architecture makes the next deletion boring.
