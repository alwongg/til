import Foundation

// I like hiding data-source details behind a repository so my view models stay boring.
protocol UserRepository {
    func loadUser(id: UUID) async throws -> User
}

struct User: Decodable {
    let id: UUID
    let name: String
}

struct APIUserRepository: UserRepository {
    let session: URLSession
    let baseURL: URL

    func loadUser(id: UUID) async throws -> User {
        let url = baseURL.appendingPathComponent("users/\(id.uuidString)")
        let (data, response) = try await session.data(from: url)

        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(User.self, from: data)
    }
}

@MainActor
final class ProfileViewModel {
    private let repository: UserRepository
    private(set) var user: User?

    init(repository: UserRepository) {
        self.repository = repository
    }

    func refresh(id: UUID) async throws {
        // The view model only asks for a user; it never learns whether the data was cached or remote.
        user = try await repository.loadUser(id: id)
    }
}
