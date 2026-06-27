// Sendable boundaries make async code predictable
//
// One thing I’ve started treating as a design tool instead of a compiler chore
// is `Sendable`.
//
// Legacy approach
// - Pass reference-heavy objects everywhere.
// - Hide mutable cache state behind classes.
// - Launch `Task {}` and trust that nothing races.
//
// Modern approach
// - Keep request/response models as small `Sendable` values.
// - Describe async work in protocols instead of sharing mutable state.
// - Move real mutation into actors.
//
// Migration strategy
// 1. Start at the edges: IDs, request models, response models, config.
// 2. Mark those types `Sendable` and let compiler errors expose hidden sharing.
// 3. Prefer actors over `@unchecked Sendable` for mutable reference state.
// 4. Use `@unchecked Sendable` only when the synchronization story is obvious.
//
// Production notes
// - `Sendable` pressure usually improves ownership and API boundaries.
// - The biggest win is predictability, not micro-performance.

import Foundation

struct UserID: Hashable, Codable, Sendable {
    let rawValue: UUID
}

struct UserProfile: Codable, Sendable {
    let id: UserID
    let name: String
    let isPro: Bool
}

protocol UserServing: Sendable {
    func fetchUser(id: UserID) async throws -> UserProfile
}

actor ProfileCache {
    private var storage: [UserID: UserProfile] = [:]

    func value(for id: UserID) -> UserProfile? {
        storage[id]
    }

    func insert(_ profile: UserProfile) {
        storage[profile.id] = profile
    }
}

struct UserService: UserServing {
    let cache: ProfileCache
    let session: URLSession

    func fetchUser(id: UserID) async throws -> UserProfile {
        if let cached = await cache.value(for: id) {
            return cached
        }

        let url = URL(string: "https://example.com/users/\(id.rawValue.uuidString)")!
        let (data, _) = try await session.data(from: url)
        let profile = try JSONDecoder().decode(UserProfile.self, from: data)
        await cache.insert(profile)
        return profile
    }
}
