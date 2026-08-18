// Architecture Patterns Evolved: A Composition Root That Makes Dependencies Honest
// 2026-08-18
//
// I used to let view models construct their own services. It felt fast until previews,
// tests, and feature flags each needed a different dependency graph. The real cost was
// hidden construction: a screen looked isolated but quietly owned networking, storage,
// and configuration decisions.
//
// ## Legacy approach
//
// final class ProfileViewModel {
//     private let api = URLSessionProfileAPI()
//     private let cache = UserDefaultsProfileCache()
// }
//
// This couples the feature to concrete infrastructure and makes a test pay for setup it
// does not care about. Replacing one dependency also means changing production code.
//
// ## Modern approach
//
// I keep protocols at the feature boundary and assemble concrete implementations once,
// at the composition root. The view model receives only what it needs.

import Foundation

struct Profile: Equatable, Sendable {
    let id: UUID
    let name: String
}

protocol ProfileFetching: Sendable {
    func profile(id: UUID) async throws -> Profile
}

protocol ProfileCaching: Sendable {
    func save(_ profile: Profile) async
}

@MainActor
final class ProfileViewModel {
    private let fetcher: any ProfileFetching
    private let cache: any ProfileCaching

    private(set) var profile: Profile?
    private(set) var errorMessage: String?

    init(fetcher: any ProfileFetching, cache: any ProfileCaching) {
        self.fetcher = fetcher
        self.cache = cache
    }

    func load(id: UUID) async {
        do {
            let profile = try await fetcher.profile(id: id)
            await cache.save(profile)
            self.profile = profile
        } catch {
            // The feature chooses presentation; infrastructure keeps its own details.
            errorMessage = "Could not load this profile."
        }
    }
}

// The app target owns this wiring. Tests and previews can build the same view model with
// fakes, without branching inside the feature.
struct AppDependencies: Sendable {
    let profileFetcher: any ProfileFetching
    let profileCache: any ProfileCaching

    @MainActor
    func makeProfileViewModel() -> ProfileViewModel {
        ProfileViewModel(fetcher: profileFetcher, cache: profileCache)
    }
}

// ## Migration strategy
// 1. Introduce a protocol beside the first concrete dependency; do not create a global
//    service locator.
// 2. Add initializer injection while retaining a temporary production convenience
//    initializer only at the app boundary.
// 3. Move construction upward one screen at a time until the composition root owns it.
// 4. Replace tests that mock globals with small fakes that model the scenario directly.
//
// ## Production notes
// A composition root is not a DI framework. For most iOS apps, a small dependency
// container plus explicit factories is easier to navigate, safer under concurrency, and
// clearer during incident debugging. I keep lifetime decisions here too: shared clients
// are created once; feature state stays feature-scoped. If the graph becomes repetitive,
// I add focused factory methods before introducing a resolver.
