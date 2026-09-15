import Foundation

// Architecture Patterns Evolved: Intent-focused use cases
// I keep UI intent and domain decisions explicit so a ViewModel stays thin
// without turning every property access into a ceremonial protocol.

struct Profile: Equatable, Sendable {
    let id: UUID
    var displayName: String
    var isNotificationsEnabled: Bool
}

protocol ProfileRepository: Sendable {
    func profile(id: UUID) async throws -> Profile
    func save(_ profile: Profile) async throws
}

enum ProfileError: Error, Equatable {
    case emptyDisplayName
}

struct UpdateProfile: Sendable {
    private let repository: any ProfileRepository

    init(repository: any ProfileRepository) {
        self.repository = repository
    }

    func callAsFunction(
        id: UUID,
        displayName: String,
        notificationsEnabled: Bool
    ) async throws -> Profile {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ProfileError.emptyDisplayName }

        var profile = try await repository.profile(id: id)
        profile.displayName = name
        profile.isNotificationsEnabled = notificationsEnabled
        try await repository.save(profile)
        return profile
    }
}

@MainActor
final class ProfileViewModel {
    enum State: Equatable {
        case idle
        case saving
        case saved(Profile)
        case failed(String)
    }

    private let updateProfile: UpdateProfile
    private let profileID: UUID
    private(set) var state: State = .idle

    init(profileID: UUID, updateProfile: UpdateProfile) {
        self.profileID = profileID
        self.updateProfile = updateProfile
    }

    func save(displayName: String, notificationsEnabled: Bool) async {
        state = .saving
        do {
            state = .saved(try await updateProfile(
                id: profileID,
                displayName: displayName,
                notificationsEnabled: notificationsEnabled
            ))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

/*
Legacy approach
I have seen ViewModels fetch, validate, mutate, save, log, and translate errors.
It ships quickly, but each new entry point duplicates business rules.

Modern approach
I model a user intent as a use case. The ViewModel owns presentation state; the
use case owns the business decision; the repository owns persistence and transport.

Migration strategy
1. Extract one high-value action first, not an entire feature.
2. Pass concrete dependencies at the composition root.
3. Add unit tests around the use case's inputs and outputs before moving more logic.

Production notes
I use a use case when an action has validation, orchestration, analytics, or more
than one caller. For a simple read-through screen, a repository injected directly
into a ViewModel is often clearer. The goal is explicit boundaries, not layers.
*/
