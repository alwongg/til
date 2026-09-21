// Async/Await Migration: Keep the Boundary, Change the Calling Code
//
// Legacy approach
// A completion-handler API forces every caller to choose a queue, thread errors
// through nested closures, and manually protect UI updates.
//
// Modern approach
// Keep the legacy API at the network boundary, then adapt it once with a checked
// continuation. The rest of the feature gets linear async code and structured
// cancellation.

import Foundation

struct Profile: Sendable, Equatable {
    let id: UUID
    let name: String
}

enum ProfileError: Error {
    case missingProfile
}

protocol LegacyProfileLoading {
    func loadProfile(
        id: UUID,
        completion: @escaping (Result<Profile, Error>) -> Void
    )
}

protocol ProfileLoading {
    func profile(id: UUID) async throws -> Profile
}

// This adapter is the migration seam. I do not leak completion handlers into
// view models or use cases while an older transport client is still in place.
final class AsyncProfileLoader: ProfileLoading {
    private let legacy: LegacyProfileLoading

    init(legacy: LegacyProfileLoading) {
        self.legacy = legacy
    }

    func profile(id: UUID) async throws -> Profile {
        try await withCheckedThrowingContinuation { continuation in
            legacy.loadProfile(id: id) { result in
                continuation.resume(with: result)
            }
        }
    }
}

@MainActor
final class ProfileViewModel {
    private let loader: ProfileLoading
    private(set) var profile: Profile?
    private(set) var errorMessage: String?

    init(loader: ProfileLoading) {
        self.loader = loader
    }

    func refresh(id: UUID) async {
        do {
            profile = try await loader.profile(id: id)
            errorMessage = nil
        } catch {
            // UI state changes stay on the main actor without dispatching back.
            errorMessage = "Could not load profile."
        }
    }
}

// Migration strategy
// 1. Wrap one stable completion-based endpoint behind an async protocol.
// 2. Move its callers to async functions; inject the protocol in tests.
// 3. Add cancellation/error mapping at this boundary, then replace the legacy
//    transport later without changing the feature layer.
//
// Production notes
// - A checked continuation must be resumed exactly once; audit every legacy path.
// - Do not wrap each caller independently: one adapter prevents inconsistent
//   queue hopping and error handling.
// - Preserve domain-specific errors instead of exposing URLSession details to UI.
