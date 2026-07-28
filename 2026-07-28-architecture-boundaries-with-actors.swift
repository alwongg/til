// Architecture Patterns Evolved: Make feature boundaries concurrency-safe
//
// Legacy approach
// I used to let a view model call URLSession directly. It was quick, but it
// mixed transport, decoding, caching, and UI state in one place. That makes
// previews brittle and turns a network change into a screen-level rewrite.
//
// Modern approach
// I put the boundary at a small repository protocol. The use case owns product
// intent, and the @MainActor view model owns only presentation state.

import Foundation

struct Profile: Sendable, Equatable {
    let id: UUID
    let name: String
}

protocol ProfileRepository: Sendable {
    func profile(id: UUID) async throws -> Profile
}

struct LoadProfile: Sendable {
    private let repository: any ProfileRepository

    init(repository: any ProfileRepository) {
        self.repository = repository
    }

    func callAsFunction(id: UUID) async throws -> Profile {
        try await repository.profile(id: id)
    }
}

@MainActor
final class ProfileViewModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded(Profile)
        case failed(String)
    }

    private let loadProfile: LoadProfile
    private(set) var state: State = .idle

    init(loadProfile: LoadProfile) {
        self.loadProfile = loadProfile
    }

    func refresh(id: UUID) async {
        state = .loading
        do {
            state = .loaded(try await loadProfile(id: id))
        } catch {
            state = .failed("Couldn't load profile. Pull to refresh to retry.")
        }
    }
}

// Migration strategy
// 1. Extract the existing API call behind a protocol without changing behaviour.
// 2. Move screen-specific decisions into a use case one path at a time.
// 3. Inject a fake repository in tests and previews before deleting old seams.
//
// Production notes
// Keep repository DTO mapping inside the repository. Make errors observable
// internally, but present recoverable language in the view model. The Sendable
// boundary also prevents an accidental non-thread-safe client from leaking into
// concurrent feature code.
