# Boundaries Are Architecture: Making Change Local

I used to describe architecture as the diagram: layers, protocols, modules, and arrows. In production, I now use a stricter test: **when a requirement changes, how many unrelated files must I touch?**

That question makes boundaries concrete. A boundary is successful when it turns an external change into a local edit.

## The legacy shape: UI learns the outside world

A common feature starts with a view model calling an API client directly. It decodes the transport DTO, chooses copy for errors, reads feature flags, and persists a cache. It ships quickly, but the UI is now coupled to networking details and vendor semantics.

When the endpoint changes, the feature is not one change. It becomes a hunt through the view model, views, tests, and sometimes several other screens that copied the same assumptions.

## The modern shape: translate at the edge

I keep the feature-facing model independent of the transport model. The repository owns translation from API response to the domain value the feature needs. A use case owns the product decision. The view model owns presentation state.

```swift
struct Profile {
    let id: UserID
    let displayName: String
}

protocol ProfileRepository {
    func profile() async throws -> Profile
}

final class LoadProfile {
    private let repository: ProfileRepository

    init(repository: ProfileRepository) {
        self.repository = repository
    }

    func callAsFunction() async throws -> Profile {
        try await repository.profile()
    }
}
```

The protocol is not valuable because it is a protocol. It is valuable because the feature depends on a stable capability (`profile()`), rather than an HTTP path, JSON schema, or SDK type.

## My migration strategy

1. **Name the volatile dependency.** I start with the part likely to change: an API, analytics vendor, persistence mechanism, or feature flag service.
2. **Introduce one feature-level interface.** I avoid a giant shared abstraction; the consumer should define the smallest capability it needs.
3. **Translate once.** I move DTO-to-domain mapping into the adapter or repository so transport types do not leak inward.
4. **Migrate one call path.** I preserve behaviour first, then delete the old direct dependency once the path is proven.
5. **Test the decision, not the machinery.** Use-case tests use a focused fake; adapter tests cover translation and error mapping.

## Production notes

- Put cancellation, retry policy, and observability at the boundary where they can be applied consistently.
- Make error mapping intentional. A feature should see product-relevant failures, not every `URLError` detail.
- Do not add layers pre-emptively. I add a boundary when a dependency is shared, volatile, expensive to test, or carrying policy the UI should not own.
- A boundary can be a closure or a tiny protocol. The smallest honest seam is usually the most maintainable one.

My architecture goal is not maximum separation. It is **local change**: the next API migration, experiment, or storage swap should disturb one adapter, while the feature continues to speak its own language.
