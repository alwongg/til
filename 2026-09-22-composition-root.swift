// Architecture Patterns Evolved: Make the Composition Root the Only Place That Knows Concrete Types
//
// I used to let view models create their own services. It felt fast: `APIClient()` in
// an initializer and the screen worked. The cost arrived later—previews needed the
// network, tests needed URLProtocol tricks, and changing persistence touched every feature.
//
// Modern approach
// I make a feature depend on narrow capabilities, then assemble concrete types at one
// composition root. The view model has no idea whether its repository is remote, cached,
// or a fixture. That is the useful part of dependency injection—not the container itself.
//
// Migration strategy
// 1. Extract the smallest protocol at a seam that already changes or is hard to test.
// 2. Inject it with a default only at the composition root, never inside the feature.
// 3. Replace one feature at a time; avoid a repo-wide protocol rewrite.
//
// Production notes
// Keep protocols owned by the consumer, not the shared service module. It prevents a
// generic “god protocol” and lets each feature ask only for the operations it needs.

import Foundation

struct Profile: Equatable, Sendable {
    let id: UUID
    let displayName: String
}

// The feature defines its own narrow contract.
protocol ProfileReading: Sendable {
    func profile(id: UUID) async throws -> Profile
}

actor RemoteProfileRepository: ProfileReading {
    func profile(id: UUID) async throws -> Profile {
        // This is where URLSession, decoding, caching, and observability belong.
        Profile(id: id, displayName: "Alex")
    }
}

@MainActor
final class ProfileViewModel {
    private let profiles: any ProfileReading
    private(set) var name = "Loading…"

    init(profiles: any ProfileReading) {
        self.profiles = profiles
    }

    func load(id: UUID) async {
        do {
            name = try await profiles.profile(id: id).displayName
        } catch {
            // A production screen maps domain failures to a user-facing state here.
            name = "Unavailable"
        }
    }
}

@MainActor
enum ProfileFeature {
    static func makeViewModel() -> ProfileViewModel {
        ProfileViewModel(profiles: RemoteProfileRepository())
    }
}

// Tests can pass a deterministic fake without networking or global registration.
struct PreviewProfiles: ProfileReading {
    func profile(id: UUID) async throws -> Profile {
        Profile(id: id, displayName: "Preview Alex")
    }
}
