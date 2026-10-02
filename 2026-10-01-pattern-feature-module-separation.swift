// Architecture Pattern: Feature Module Separation
//
// I keep each feature flowing in one direction:
// Model -> Repository -> UseCase -> ViewModel -> View.
// The view never knows where data came from, so a network client can become
// a cache, fixture, or preview without rewriting presentation logic.

import Foundation

struct Profile: Equatable {
    let id: UUID
    let displayName: String
}

protocol ProfileRepository {
    func profile(id: UUID) async throws -> Profile
}

struct LoadProfile {
    let repository: any ProfileRepository

    func callAsFunction(id: UUID) async throws -> Profile {
        try await repository.profile(id: id)
    }
}

@MainActor
final class ProfileViewModel {
    private let loadProfile: LoadProfile
    private(set) var name = ""

    init(loadProfile: LoadProfile) {
        self.loadProfile = loadProfile
    }

    func refresh(id: UUID) async {
        do {
            name = try await loadProfile(id: id).displayName
        } catch {
            name = "Unavailable"
        }
    }
}

// My SwiftUI view owns rendering and user intent only; composition happens
// outside this module, where production and preview dependencies can differ.
