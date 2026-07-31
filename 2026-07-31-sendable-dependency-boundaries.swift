# Production Pattern: Make Dependency Boundaries Sendable Before Strict Concurrency Does It For Me

I treat Swift 6 concurrency warnings as architecture feedback. When a service cannot cross an actor boundary, the problem is usually not the annotation—it is that I let mutable, framework-shaped dependencies leak too far into the app.

## Legacy approach

I used to inject a reference-type API client directly into view models. It was convenient, but its mutable configuration and callbacks made ownership unclear. Marking it `@unchecked Sendable` would silence the compiler while preserving the race.

## Modern approach

I expose a small `Sendable` protocol and make the implementation an `actor`. The domain receives immutable request and response values, not a networking object with ambient state. The actor owns its mutation; callers only await a value.

```swift
import Foundation

struct UserID: Sendable, Hashable { let rawValue: String }
struct User: Sendable, Decodable { let id: String; let name: String }

protocol UserLoading: Sendable {
    func loadUser(id: UserID) async throws -> User
}

actor RemoteUserLoader: UserLoading {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func loadUser(id: UserID) async throws -> User {
        let url = baseURL.appending(path: "users").appending(path: id.rawValue)
        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(User.self, from: data)
    }
}

@MainActor
final class ProfileViewModel {
    private let loader: any UserLoading
    private(set) var user: User?

    init(loader: some UserLoading) { self.loader = loader }

    func refresh(id: UserID) async {
        do { user = try await loader.loadUser(id: id) }
        catch { user = nil }
    }
}
```

## Migration strategy

1. Start at the boundary: make request, response, and identifier types `Sendable`.
2. Replace closure callbacks with `async` protocol requirements.
3. Move mutable client state behind an actor instead of adding `@unchecked Sendable`.
4. Keep UI mutation in a `@MainActor` view model; pass only values across the boundary.

## Production notes

- I inject `URLSession` so tests can use a deterministic session configuration, while the actor preserves serialization of any future mutable state such as an auth refresh token.
- I keep the protocol narrow. A giant `APIClient` protocol spreads transport details and makes concurrency migration harder.
- `Sendable` is not a performance feature; it documents safe ownership. I still avoid unnecessarily moving large mutable graphs between tasks.
- I enable strict concurrency before a large refactor. The diagnostics identify the real seams worth isolating.
