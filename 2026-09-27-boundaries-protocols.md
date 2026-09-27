# Architecture Thinking: Boundaries Are Protocols

When I inherit a messy iOS feature, I stop asking which framework should own it. I ask which **protocol** the feature needs to keep working when the implementation changes.

A boundary is useful when it protects a policy decision from a volatile detail. Network clients, persistence stores, and analytics SDKs change. The feature's intent should not.

## Legacy approach: let the detail leak

```swift
final class ProfileViewModel: ObservableObject {
    private let api = URLSession.shared

    func loadProfile() async throws {
        let url = URL(string: "https://example.com/profile")!
        let (data, _) = try await api.data(from: url)
        // Decode, map errors, and decide UI state here.
    }
}
```

This looks small, but the view model now knows transport, endpoint construction, decoding, and error policy. A preview, test, or cache cannot replace one concern without carrying all the others.

## Modern approach: name the capability

```swift
struct Profile: Sendable, Equatable {
    let id: String
    let displayName: String
}

protocol ProfileLoading: Sendable {
    func profile(id: String) async throws -> Profile
}

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var profile: Profile?
    private let loader: any ProfileLoading

    init(loader: any ProfileLoading) {
        self.loader = loader
    }

    func load(id: String) async {
        do {
            profile = try await loader.profile(id: id)
        } catch {
            // Map the domain failure into UI state at this boundary.
        }
    }
}
```

`ProfileLoading` is intentionally smaller than a generic `APIClient`. It states what this feature needs, not how the app reaches the server. The live implementation can use `URLSession`; previews can use a fixture; tests can use a deterministic fake.

## Migration strategy

1. Pick one volatile dependency that is making a feature hard to test or preview.
2. Define a feature-owned protocol around the capability, with domain inputs and outputs.
3. Adapt the existing client behind that protocol instead of rewriting the networking stack.
4. Inject the adapter at the composition root, then replace test setup with a fake.
5. Keep the protocol only while it protects a real seam. I do not add abstractions for hypothetical swaps.

## Production notes

- I keep protocols close to their consumer. A global protocol directory usually becomes a second API surface nobody owns.
- I model cancellation and errors deliberately: cancellation should remain cancellation, while server failures should become useful domain failures.
- `Sendable` makes the concurrency expectation explicit. If an implementation touches non-sendable SDK state, I isolate that implementation rather than weakening the whole feature boundary.
- The composition root is where I accept concrete types. Everywhere else should depend on capabilities and domain models.

The goal is not maximum abstraction. The goal is a small, named contract that lets the feature evolve without dragging infrastructure decisions through every screen.
