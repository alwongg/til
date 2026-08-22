// Architecture Pattern: Lightweight Dependency Injection Container
// I keep construction at the app boundary so feature code depends on behaviour, not globals.

import Foundation

struct Profile: Codable, Sendable {
    let id: UUID
    let displayName: String
}

protocol APIClient: Sendable {
    func profile(id: UUID) async throws -> Profile
}

protocol ProfileRepository: Sendable {
    func profile(id: UUID) async throws -> Profile
}

struct LiveProfileRepository<Client: APIClient>: ProfileRepository {
    let client: Client

    func profile(id: UUID) async throws -> Profile {
        try await client.profile(id: id)
    }
}

enum AppFactory {
    // This is the composition root: swapping environments stays explicit and testable.
    static func makeProfileRepository<Client: APIClient>(
        client: Client
    ) -> any ProfileRepository {
        LiveProfileRepository(client: client)
    }
}

@MainActor
final class ProfileViewModel {
    private let repository: any ProfileRepository

    init(repository: any ProfileRepository) {
        self.repository = repository
    }
}
