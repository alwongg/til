import Foundation

// 2026-06-08 — Swift Language Evolution
// Title: From Locks and Shared State to Actors
//
// I still inherit code that protects shared mutable state with manual locking.
// It can work, but the correctness burden lives in every call site and every
// future edit. When I can target modern Swift concurrency, actors are the
// upgrade path I trust more in production.

struct Profile: Codable, Sendable {
    let id: UUID
    let name: String
}

enum CacheError: Error {
    case missingProfile(UUID)
}

// Legacy approach: a reference type plus a lock. The code is easy to write,
// but thread-safety depends on remembering the locking discipline everywhere.
final class ProfileCacheLegacy {
    private var storage: [UUID: Profile] = [:]
    private let lock = NSLock()

    func save(_ profile: Profile) {
        lock.lock()
        defer { lock.unlock() }
        storage[profile.id] = profile
    }

    func load(id: UUID) throws -> Profile {
        lock.lock()
        defer { lock.unlock() }

        guard let profile = storage[id] else {
            throw CacheError.missingProfile(id)
        }
        return profile
    }

    func replaceAll(with profiles: [Profile]) {
        lock.lock()
        defer { lock.unlock() }
        storage = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
    }
}

// Modern approach: the actor owns mutation and Swift enforces isolation for me.
actor ProfileCache {
    private var storage: [UUID: Profile] = [:]

    func save(_ profile: Profile) {
        storage[profile.id] = profile
    }

    func load(id: UUID) throws -> Profile {
        guard let profile = storage[id] else {
            throw CacheError.missingProfile(id)
        }
        return profile
    }

    func replaceAll(with profiles: [Profile]) {
        storage = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
    }

    func count() -> Int {
        storage.count
    }
}

// Migration strategy:
// 1. I identify the type that truly owns the shared mutable state.
// 2. I convert that type to an actor before changing all of its consumers.
// 3. I let async boundaries appear at the edges, then update callers one layer at a time.
// 4. I keep domain errors and API naming stable so the migration stays mechanical.

struct ProfileRepository {
    private let cache = ProfileCache()

    func warmCache() async {
        await cache.replaceAll(with: [
            Profile(id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!, name: "Mochi"),
            Profile(id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!, name: "Alex")
        ])
    }

    func profileName(for id: UUID) async -> String {
        do {
            return try await cache.load(id: id).name
        } catch {
            return "Unknown"
        }
    }
}

// Production notes:
// - Actors reduce the surface area for race conditions, but I still watch for
//   reentrancy if actor methods await other work before finishing a mutation.
// - I try to keep actor APIs focused and value-oriented so call sites stay clear.
// - If a dependency has to stay synchronous for a while, I migrate the state owner
//   first and bridge outward rather than sprinkling locks across new code.
// - The biggest payoff is not syntax. It is that concurrency rules become visible
//   in the type system instead of living in team folklore.

@main
struct DemoApp {
    static func main() async {
        let repository = ProfileRepository()
        await repository.warmCache()

        let alexID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let name = await repository.profileName(for: alexID)
        print("Loaded profile: \(name)")
    }
}
