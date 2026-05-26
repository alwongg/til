import Foundation

// 2026-05-26 — Architecture Patterns Evolved
// Title: From Massive View Controllers to Feature Pipelines
//
// I still inherit screens where the controller owns fetching, mapping, caching,
// and presentation decisions all at once. It ships quickly the first time,
// but every new requirement turns into another conditional branch. This is the
// architecture transformation I reach for when I want cleaner seams.

struct Profile: Decodable {
    let id: UUID
    let name: String
    let bio: String
}

// Legacy approach: one type owns transport, mapping, and UI-facing state.
final class LegacyProfileController {
    private(set) var titleText = ""
    private(set) var subtitleText = ""

    func loadProfile(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        let url = URL(string: "https://example.com/profiles/\(id.uuidString)")!

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                completion(.failure(URLError(.badServerResponse)))
                return
            }

            guard let data else {
                completion(.failure(URLError(.zeroByteResource)))
                return
            }

            do {
                let profile = try JSONDecoder().decode(Profile.self, from: data)
                self.titleText = profile.name
                self.subtitleText = profile.bio
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

// Modern approach: each layer has one job.
protocol ProfileRepository {
    func fetchProfile(id: UUID) async throws -> Profile
}

struct APIProfileRepository: ProfileRepository {
    let session: URLSession
    let baseURL: URL

    func fetchProfile(id: UUID) async throws -> Profile {
        let url = baseURL.appendingPathComponent("profiles/\(id.uuidString)")
        let (data, response) = try await session.data(from: url)

        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(Profile.self, from: data)
    }
}

struct LoadProfileUseCase {
    let repository: ProfileRepository

    func execute(id: UUID) async throws -> Profile {
        // This is where I add policy later: caching, retries, analytics, or feature gates.
        try await repository.fetchProfile(id: id)
    }
}

struct ProfileViewState {
    let title: String
    let subtitle: String
}

@MainActor
final class ProfileViewModel {
    private let loadProfile: LoadProfileUseCase
    private(set) var state = ProfileViewState(title: "Loading...", subtitle: "")

    init(loadProfile: LoadProfileUseCase) {
        self.loadProfile = loadProfile
    }

    func refresh(id: UUID) async throws {
        let profile = try await loadProfile.execute(id: id)
        state = ProfileViewState(title: profile.name, subtitle: profile.bio)
    }
}

// Migration strategy:
// 1. Extract repository behavior first without changing screen behavior.
// 2. Introduce a use case when multiple screens share the same business rule.
// 3. Move formatting into a view model so views stop knowing transport details.
// 4. Keep the old controller alive temporarily by bridging it to the new stack.
final class BridgedProfileController {
    private let viewModel: ProfileViewModel

    init(viewModel: ProfileViewModel) {
        self.viewModel = viewModel
    }

    func loadProfile(id: UUID, completion: @escaping (Result<ProfileViewState, Error>) -> Void) {
        Task {
            do {
                try await viewModel.refresh(id: id)
                completion(.success(viewModel.state))
            } catch {
                completion(.failure(error))
            }
        }
    }
}

// Production notes:
// - Repositories become great seams for tests because I can swap in a stub instantly.
// - Use cases keep feature policy centralized instead of scattered across screens.
// - View models make analytics and loading/error state easier to evolve without touching transport.
// - I prefer this feature pipeline shape once a screen starts coordinating multiple dependencies.

struct StubProfileRepository: ProfileRepository {
    func fetchProfile(id: UUID) async throws -> Profile {
        Profile(id: id, name: "Alex", bio: "Shipping cleaner iOS features with smaller seams.")
    }
}

@main
struct DemoApp {
    static func main() async {
        let useCase = LoadProfileUseCase(repository: StubProfileRepository())
        let viewModel = await ProfileViewModel(loadProfile: useCase)
        let profileID = UUID()

        do {
            try await viewModel.refresh(id: profileID)
            let state = await viewModel.state
            print("Title: \(state.title)")
            print("Subtitle: \(state.subtitle)")
        } catch {
            print("Failed to refresh profile: \(error)")
        }
    }
}
