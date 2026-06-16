# Slot 4/4 — Architecture Pattern: Repository Pattern

I use a repository when I want the rest of the app to ask for domain data without caring whether it came from memory, disk, or the network. The main win is not abstraction for its own sake — it is keeping transport and caching decisions out of the view model.

```swift
import Foundation

struct User: Sendable {
    let id: UUID
    let name: String
}

protocol UserRepository {
    func user(id: UUID) async throws -> User
}

struct RemoteUserRepository: UserRepository {
    let fetch: @Sendable (UUID) async throws -> User

    func user(id: UUID) async throws -> User {
        try await fetch(id)
    }
}

actor CachedUserRepository: UserRepository {
    private let upstream: UserRepository
    private var cache: [UUID: User] = [:]

    init(upstream: UserRepository) {
        self.upstream = upstream
    }

    func user(id: UUID) async throws -> User {
        if let cached = cache[id] { return cached }
        let loaded = try await upstream.user(id: id)
        cache[id] = loaded
        return loaded
    }
}
```

Why I like this shape:
- The protocol is tiny, so swapping implementations stays cheap.
- Caching is a decorator concern instead of leaking into screens.
- Tests can inject a stub repository instead of mocking URLSession.

Production note: I keep mapping from DTOs to domain models inside the repository boundary. That keeps the rest of the app stable even if the API changes.
