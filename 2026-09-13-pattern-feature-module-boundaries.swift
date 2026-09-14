// Architecture Pattern: Feature Module Boundaries
// I keep business rules out of both the view model and networking layer. The
// dependency direction stays one-way: View -> ViewModel -> UseCase -> Repository.

import Foundation

struct Profile: Equatable, Sendable {
    let id: UUID
    let displayName: String
}

protocol ProfileRepository: Sendable {
    func profile(id: UUID) async throws -> Profile
}

struct LoadProfileUseCase: Sendable {
    private let repository: any ProfileRepository

    init(repository: any ProfileRepository) {
        self.repository = repository
    }

    func callAsFunction(id: UUID) async throws -> Profile {
        // This is where I add product rules without coupling them to transport.
        try await repository.profile(id: id)
    }
}

@MainActor
final class ProfileViewModel {
    private let loadProfile: LoadProfileUseCase
    private(set) var name = ""

    init(loadProfile: LoadProfileUseCase) {
        self.loadProfile = loadProfile
    }

    func refresh(id: UUID) async {
        do { name = try await loadProfile(id: id).displayName }
        catch { name = "Unavailable" }
    }
}

// The app target composes concrete repositories; the feature depends only on its protocol.
