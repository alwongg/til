import Foundation

// I keep UI-facing state on the main actor, while the use case stays portable and testable.
struct Profile: Sendable, Equatable {
    let id: UUID
    let name: String
}

protocol ProfileFetching: Sendable {
    func profile(id: UUID) async throws -> Profile
}

// The use case owns application policy: this is where I normalize the boundary
// between infrastructure failures and what the feature is allowed to display.
struct LoadProfile: Sendable {
    let repository: any ProfileFetching

    func callAsFunction(id: UUID) async throws -> Profile {
        let profile = try await repository.profile(id: id)
        guard !profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProfileError.invalidProfile
        }
        return profile
    }
}

enum ProfileError: Error, Equatable {
    case invalidProfile
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

    func load(id: UUID) async {
        state = .loading
        do {
            state = .loaded(try await loadProfile(id: id))
        } catch {
            // I deliberately translate errors at the presentation edge, not in the repository.
            state = .failed("I couldn't load this profile. Please try again.")
        }
    }
}

struct PreviewProfileRepository: ProfileFetching {
    func profile(id: UUID) async throws -> Profile {
        Profile(id: id, name: "Alex")
    }
}
