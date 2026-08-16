// Architecture Pattern: Repository Boundary
//
// I keep persistence and transport details behind a repository so my view models
// depend on a stable domain API. Swapping a live client for a fixture becomes a
// composition-root decision, not a UI rewrite.

import Foundation

struct Profile: Codable, Sendable, Equatable {
    let id: UUID
    let name: String
}

protocol ProfileRepository: Sendable {
    func profile(id: UUID) async throws -> Profile
}

actor InMemoryProfileRepository: ProfileRepository {
    private var storage: [UUID: Profile]

    init(profiles: [Profile]) {
        storage = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
    }

    func profile(id: UUID) throws -> Profile {
        // The repository owns lookup semantics; callers do not learn storage details.
        guard let profile = storage[id] else { throw RepositoryError.notFound }
        return profile
    }
}

enum RepositoryError: Error { case notFound }

@MainActor
final class ProfileViewModel {
    private let repository: any ProfileRepository
    private(set) var name = ""

    init(repository: any ProfileRepository) { self.repository = repository }

    func load(id: UUID) async throws {
        name = try await repository.profile(id: id).name
    }
}
