// 2026-06-30 — Architecture Patterns Evolved: Ports over singletons
//
// I used to hide architecture problems with a "clean enough" singleton graph:
// views knew about concrete services, services knew about persistence, and tests
// paid the price. The modern shift I care about is smaller than a full rewrite:
// I define ports at the feature boundary, then plug implementations in behind them.
//
// Legacy approach
// - ViewModel imported concrete API clients directly.
// - Caching, retry, and mapping logic leaked upward.
// - Tests mocked too much surface area because dependencies were too wide.
//
// Modern approach
// - The feature depends on a narrow repository port.
// - Infrastructure lives behind the port and can evolve independently.
// - Concurrency boundaries become explicit when the implementation is an actor.
//
// Migration strategy
// 1. Introduce one protocol at the seam I want to stabilize.
// 2. Move orchestration logic into the repository implementation.
// 3. Inject the port into the ViewModel before touching the rest of the module graph.
// 4. Delete singleton access from the feature once tests are green.
//
// Production notes
// - Prefer feature-shaped ports, not generic "DataService" abstractions.
// - Actor-backed repositories are a clean place for cache + request coalescing.
// - Keep the ViewModel focused on state transitions, not integration details.

import Foundation

struct User: Sendable {
    let id: Int
    let name: String
}

protocol UserRepository: Sendable {
    func loadUser(id: Int) async throws -> User
}

actor LiveUserRepository: UserRepository {
    private var cache: [Int: User] = [:]

    func loadUser(id: Int) async throws -> User {
        if let cached = cache[id] { return cached }

        // In production this would call a client, map DTOs, and persist if needed.
        let user = User(id: id, name: "Alex")
        cache[id] = user
        return user
    }
}

@MainActor
final class ProfileViewModel {
    private let repository: UserRepository
    private(set) var title = "Loading..."

    init(repository: UserRepository) {
        self.repository = repository
    }

    func refresh(userID: Int) async {
        do {
            let user = try await repository.loadUser(id: userID)
            title = "Welcome, \(user.name)"
        } catch {
            title = "Failed to load profile"
        }
    }
}

@main
struct DemoApp {
    static func main() async {
        let viewModel = ProfileViewModel(repository: LiveUserRepository())
        await viewModel.refresh(userID: 42)
        print(viewModel.title)
    }
}
