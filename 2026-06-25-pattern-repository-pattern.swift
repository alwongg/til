// Repository Pattern
// I use a repository when I want my app code to depend on business intent,
// not on whether the data came from memory, disk, or the network.
//
// The useful boundary is not “API client vs database.”
// It is “what does this feature need to read and write?”
// Once I encode that as a protocol, my use case stays testable and the
// storage choice becomes a replaceable detail.

import Foundation

struct User: Identifiable, Codable {
    let id: UUID
    var name: String
}

enum RepositoryError: Error {
    case notFound
}

protocol UserRepository {
    func user(id: UUID) async throws -> User
    func save(_ user: User) async throws
}

actor InMemoryUserRepository: UserRepository {
    private var storage: [UUID: User]

    init(seed: [User] = []) {
        storage = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
    }

    func user(id: UUID) async throws -> User {
        guard let user = storage[id] else { throw RepositoryError.notFound }
        return user
    }

    func save(_ user: User) async throws {
        storage[user.id] = user
    }
}

struct RenameUserUseCase {
    let repository: UserRepository

    func execute(id: UUID, newName: String) async throws -> User {
        var user = try await repository.user(id: id)
        user.name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        try await repository.save(user)
        return user
    }
}

@main
enum Demo {
    static func main() async throws {
        let original = User(id: UUID(), name: "Legacy Alex")
        let repository = InMemoryUserRepository(seed: [original])
        let useCase = RenameUserUseCase(repository: repository)
        let updated = try await useCase.execute(id: original.id, newName: "Alex")
        print(updated.name)
    }
}
