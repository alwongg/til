# Decision Boundaries Over Shared Abstractions

I keep relearning the same architecture lesson: most iOS complexity does not come from missing abstractions. It comes from unclear decision ownership.

## Legacy approach

When a codebase starts to sprawl, the reflex is usually to add a shared manager, a base view model, or a convenience service that multiple features can reach into. It feels efficient because duplication drops fast.

The cost shows up later:
- business rules drift into global helpers
- features stop owning their own loading, caching, and retry choices
- tests become mock-heavy because everything depends on the same giant surface area
- one “small” change turns into a cross-feature regression hunt

In practice, shared abstractions often hide a missing decision boundary.

## Modern approach

What I want instead is a system where each layer owns a narrow kind of decision:

- **View** owns rendering and user intent mapping
- **ViewModel / Presenter** owns screen state transitions
- **UseCase** owns business sequencing
- **Repository** owns data access strategy
- **Client** owns transport details

That layering is not new. The shift is being strict about **where a decision is allowed to live**.

A repository should decide whether data comes from cache, disk, or network. A view model should decide whether the UI shows skeletons, stale data, or retry affordances. If both layers make the same decision, the architecture is already leaking.

## Transformation example

Instead of this:

```swift
final class FeedManager {
    func loadFeed(forceRefresh: Bool) async throws -> [Post] {
        // cache policy, request building, decoding, analytics,
        // retry behavior, and mapping all live here
    }
}
```

I prefer something closer to:

```swift
protocol FeedRepository {
    func fetchFeed(policy: FetchPolicy) async throws -> [PostDTO]
}

struct LoadFeedUseCase {
    let repository: FeedRepository

    func execute(isPullToRefresh: Bool) async throws -> [Post] {
        let policy: FetchPolicy = isPullToRefresh ? .refresh : .cachedThenRefresh
        return try await repository
            .fetchFeed(policy: policy)
            .map(Post.init)
    }
}
```

The important part is not the protocol. It is that refresh policy is now a business decision owned by the use case, not buried in a grab-bag manager.

## Migration strategy

When I refactor toward this style, I do it in a tight order:

1. identify one unstable user flow
2. write down the decisions that flow makes
3. move each decision to the layer that should own it
4. leave pure reuse behind in helpers, but move branching logic out
5. delete the old shared entry point once one feature is clean end-to-end

This avoids “architecture rewrites” that rename everything without changing responsibility.

## Production notes

- Shared code is healthiest when it shares mechanics, not policy.
- If a dependency needs ten mocks to test one screen, responsibility is probably misplaced.
- If two features need different retry, caching, or sorting behavior, they should not be forced through one convenience API.
- Good architecture reduces surprise more than it reduces line count.

That is the lens I trust most now: before creating a new abstraction, I ask which layer should own this decision and whether I am about to hide that answer instead of making it explicit.
