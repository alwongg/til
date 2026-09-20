// Repository Pattern: Keep Remote Details Out of Feature State
//
// I use a repository when a feature needs a stable domain-facing contract while
// transport, caching, and decoding are free to change behind it. My view model
// asks for a User; it does not know whether that User came from URLSession, disk,
// or a test fixture. The protocol is deliberately small so it stays a boundary,
// not an abstraction museum.

import Foundation

struct User: Sendable, Equatable {
    let id: UUID
    let name: String
}

protocol UserRepository: Sendable {
    func user(id: UUID) async throws -> User
}

enum UserRepositoryError: Error {
    case notFound(UUID)
}

actor InMemoryUserRepository: UserRepository {
    private var users: [UUID: User]

    init(users: [User]) {
        self.users = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
    }

    func user(id: UUID) throws -> User {
        // The feature gets a domain error, not a storage-specific lookup failure.
        guard let user = users[id] else { throw UserRepositoryError.notFound(id) }
        return user
    }
}

@MainActor
final class ProfileViewModel {
    private let repository: any UserRepository
    private(set) var displayName = ""

    init(repository: any UserRepository) {
        self.repository = repository
    }

    func load(id: UUID) async {
        do { displayName = try await repository.user(id: id).name }
        catch { displayName = "Unavailable" }
    }
}

// Migration: extract one read path first, inject the concrete repository at the
// composition root, then move caching and request mapping behind the same contract.
// In production I keep this protocol feature-owned; sharing it too early leaks one
// feature's needs into every other caller.
