import Foundation

// I keep persistence behind a protocol so the feature can be tested without a database.
struct Profile: Equatable, Sendable {
    let id: UUID
    var displayName: String
}

protocol ProfileRepository: Sendable {
    func profile(id: UUID) async throws -> Profile?
    func save(_ profile: Profile) async throws
}

actor InMemoryProfileRepository: ProfileRepository {
    private var storage: [UUID: Profile] = [:]

    func profile(id: UUID) async throws -> Profile? {
        storage[id]
    }

    func save(_ profile: Profile) async throws {
        storage[profile.id] = profile
    }
}

struct RenameProfile {
    let repository: any ProfileRepository

    func callAsFunction(id: UUID, name: String) async throws -> Profile {
        guard var profile = try await repository.profile(id: id) else {
            throw CocoaError(.fileNoSuchFile)
        }
        profile.displayName = name
        try await repository.save(profile)
        return profile
    }
}
