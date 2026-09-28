// # Evolving a concrete service into a dependency boundary
//
// ## Legacy approach
// I used to inject a concrete `URLSessionProfileAPI` into view models. It was
// convenient, but it made previews, tests, retries, and a future cache all
// depend on the networking implementation.
//
// ## Modern approach
// I make the app depend on a small async protocol and keep URLSession behind
// that boundary. The protocol models the capability I need—not the framework
// I happen to use today.
//
// ## Migration strategy
// 1. Extract the narrowest protocol at the consuming feature.
// 2. Make the existing concrete service conform without changing behavior.
// 3. Inject the protocol into the view model, then add fakes in tests/previews.
// 4. Add caching or retries as decorators rather than growing the view model.
//
// ## Production notes
// Keep transport DTOs private to the API layer. Cancellation naturally reaches
// URLSession through `await`, and errors stay typed at the boundary so the UI
// can decide whether to retry, render an empty state, or surface a message.

import Foundation

struct Profile: Decodable, Sendable, Equatable {
    let id: UUID
    let displayName: String
}

protocol ProfileFetching: Sendable {
    func profile(id: UUID) async throws -> Profile
}

enum ProfileAPIError: Error, Equatable {
    case invalidResponse
}

struct URLSessionProfileAPI: ProfileFetching {
    private let session: URLSession
    private let baseURL: URL

    init(session: URLSession = .shared, baseURL: URL) {
        self.session = session
        self.baseURL = baseURL
    }

    func profile(id: UUID) async throws -> Profile {
        let url = baseURL.appending(path: "profiles/\(id.uuidString)")
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw ProfileAPIError.invalidResponse
        }
        return try JSONDecoder().decode(Profile.self, from: data)
    }
}

@MainActor
final class ProfileViewModel {
    private let profileAPI: any ProfileFetching
    private(set) var profile: Profile?

    init(profileAPI: any ProfileFetching) {
        self.profileAPI = profileAPI
    }

    func load(id: UUID) async throws {
        // The UI owns presentation state; the boundary owns retrieval details.
        profile = try await profileAPI.profile(id: id)
    }
}

struct PreviewProfileAPI: ProfileFetching {
    func profile(id: UUID) async throws -> Profile {
        Profile(id: id, displayName: "Preview Alex")
    }
}
