# Strict Concurrency Is an API Evolution, Not a Rewrite

I treat `async`/`await` as a way to modernize an API boundary without forcing every caller to migrate at once. The old completion-based protocol stays intact; a small adapter gives new code a structured-concurrency entry point. An actor then owns the cache, so concurrent requests cannot race each other.

## Legacy boundary

```swift
protocol ProfileFetching {
    func fetchProfile(
        id: String,
        completion: @escaping (Result<Profile, Error>) -> Void
    )
}
```

Completion handlers made cancellation, error propagation, and ordering every caller's responsibility. Replacing this protocol outright creates a broad migration and often blocks unrelated feature work.

## Modern boundary

```swift
import Foundation

struct Profile: Codable, Sendable {
    let id: String
    let displayName: String
}

protocol ProfileFetching {
    func fetchProfile(
        id: String,
        completion: @escaping (Result<Profile, Error>) -> Void
    )
}

extension ProfileFetching {
    func profile(id: String) async throws -> Profile {
        try await withCheckedThrowingContinuation { continuation in
            fetchProfile(id: id) { result in
                continuation.resume(with: result)
            }
        }
    }
}

actor ProfileStore {
    private let remote: any ProfileFetching
    private var cache: [String: Profile] = [:]

    init(remote: any ProfileFetching) {
        self.remote = remote
    }

    func profile(id: String) async throws -> Profile {
        if let cached = cache[id] {
            return cached
        }

        let loaded = try await remote.profile(id: id)
        cache[id] = loaded // The actor serializes cache mutation.
        return loaded
    }
}
```

## Migration strategy

1. Keep the callback requirement at the networking boundary while existing implementations remain in service.
2. Add the async adapter in an extension, so feature code can migrate screen by screen.
3. Put shared mutable state behind an actor before parallel tasks begin using it.
4. Once callback callers reach zero, promote the async method into the protocol and delete the bridge.

## Production notes

`withCheckedThrowingContinuation` is a bridge, not a substitute for a correct callback contract: the implementation must resume exactly once. I also keep the actor narrow. It protects cache invariants; it does not make every network request serial. If duplicate in-flight fetches become expensive, my next step is an actor-owned task dictionary for request coalescing, with explicit cancellation policy.
