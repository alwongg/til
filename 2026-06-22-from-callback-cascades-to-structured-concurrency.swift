import Foundation

// From callback cascades to structured concurrency
//
// Legacy approach
// I still run into older service layers that expose nested completion handlers.
// They work, but they spread error handling across multiple closures and make
// cancellation mostly a convention instead of a language feature.
//
// Modern approach
// My default now is to wrap the old API once, then let the rest of the feature
// speak async/await. The important shift is not cosmetic. Once the boundary is
// async, retries, parallel fetches, task cancellation, and actor isolation all
// become much easier to reason about.
//
// Migration strategy
// 1. Keep the legacy client stable so I do not rewrite transport code mid-flight.
// 2. Add async adapters in an extension.
// 3. Move feature orchestration into an actor so mutable state stops leaking.
// 4. Let view models consume the actor instead of touching callback APIs.
//
// Production notes
// - Resume continuations exactly once.
// - Propagate CancellationError deliberately when the caller backs out.
// - Use the adapter seam as the place to normalize transport errors.
// - Migrate call sites feature-by-feature instead of doing a repo-wide flip.

enum ProfileError: Error {
    case notFound
    case transport
}

struct Profile: Sendable, Equatable {
    let id: String
    let displayName: String
    let isPro: Bool
}

final class LegacyProfileClient {
    func fetchProfile(
        id: String,
        completion: @escaping (Result<Profile, Error>) -> Void
    ) {
        // I keep the legacy shape here because this is the boundary I usually
        // do not want to destabilize during a migration.
        let profile = Profile(id: id, displayName: "Alex", isPro: true)
        completion(.success(profile))
    }
}

extension LegacyProfileClient {
    func fetchProfile(id: String) async throws -> Profile {
        try Task.checkCancellation()

        return try await withCheckedThrowingContinuation { continuation in
            fetchProfile(id: id) { result in
                continuation.resume(with: result)
            }
        }
    }
}

actor ProfileRepository {
    private let client: LegacyProfileClient
    private var cache: [String: Profile] = [:]

    init(client: LegacyProfileClient) {
        self.client = client
    }

    func profile(id: String, forceRefresh: Bool = false) async throws -> Profile {
        if !forceRefresh, let cached = cache[id] {
            return cached
        }

        let fresh = try await client.fetchProfile(id: id)
        cache[id] = fresh
        return fresh
    }

    func proDisplayNames(ids: [String]) async throws -> [String] {
        try await withThrowingTaskGroup(of: Profile.self) { group in
            for id in ids {
                group.addTask {
                    try await self.profile(id: id)
                }
            }

            var names: [String] = []
            for try await profile in group {
                if profile.isPro {
                    names.append(profile.displayName)
                }
            }
            return names.sorted()
        }
    }
}

struct ProfileViewState: Sendable {
    let title: String
    let badge: String

    init(profile: Profile) {
        title = profile.displayName
        badge = profile.isPro ? "PRO" : "FREE"
    }
}

@MainActor
final class ProfileViewModel {
    private let repository: ProfileRepository
    private(set) var state: ProfileViewState?

    init(repository: ProfileRepository) {
        self.repository = repository
    }

    func load(id: String) async {
        do {
            let profile = try await repository.profile(id: id)
            state = ProfileViewState(profile: profile)
        } catch is CancellationError {
            // I treat cancellation as control flow, not a UI error.
            state = nil
        } catch {
            state = nil
        }
    }
}

@main
struct LessonDemo {
    static func main() async {
        let repository = ProfileRepository(client: LegacyProfileClient())
        let viewModel = ProfileViewModel(repository: repository)
        await viewModel.load(id: "42")
        _ = try? await repository.proDisplayNames(ids: ["42", "7", "9"])
    }
}
