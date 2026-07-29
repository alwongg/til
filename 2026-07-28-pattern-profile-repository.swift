# Repository Pattern: Keep Persistence Behind a Small Contract

I use a repository to keep a feature’s language independent from where its data lives. A view model asks for `Profile`; it should not need to know whether that came from `URLSession`, SwiftData, or a fixture.

```swift
import Foundation

struct Profile: Codable, Sendable, Equatable {
    let id: UUID
    let name: String
}

protocol ProfileRepository: Sendable {
    func profile(id: UUID) async throws -> Profile
}

struct RemoteProfileRepository: ProfileRepository {
    let load: @Sendable (UUID) async throws -> Data

    func profile(id: UUID) async throws -> Profile {
        let data = try await load(id)
        return try JSONDecoder().decode(Profile.self, from: data)
    }
}

struct ProfileViewModel {
    private let repository: any ProfileRepository

    init(repository: any ProfileRepository) {
        self.repository = repository
    }

    func loadProfile(id: UUID) async throws -> Profile {
        try await repository.profile(id: id)
    }
}

struct PreviewProfileRepository: ProfileRepository {
    func profile(id: UUID) async throws -> Profile {
        Profile(id: id, name: "Preview Alex")
    }
}
```

The important boundary is the protocol, not the number of repository types. I keep it feature-shaped: `profile(id:)` says what the Profile feature needs, instead of exposing generic database or request primitives.

At composition time, I inject `RemoteProfileRepository` in production and `PreviewProfileRepository` in previews or deterministic tests. That keeps the view model honest: it depends on the behavior it needs, while transport, decoding, caching, and retries can evolve behind the repository without leaking upward.
