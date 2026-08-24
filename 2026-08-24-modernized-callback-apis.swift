import Foundation

// Swift Language Evolution: moving a callback-based API client to Swift concurrency
//
// Legacy approach:
// func loadUser(id: UUID, completion: @escaping (Result<User, Error>) -> Void) {
//     session.dataTask(with: request(for: id)) { data, response, error in
//         // Every caller owns error handling, decoding, and thread hopping.
//     }.resume()
// }
//
// I treat this as a boundary migration, not a rewrite. A completion closure hides
// cancellation, encourages nested calls, and lets UI code accidentally own queues.

protocol HTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPClient {}

struct User: Decodable, Sendable {
    let id: UUID
    let name: String
}

enum APIError: Error, Sendable {
    case invalidResponse
    case badStatus(Int)
}

actor APIClient {
    private let session: any HTTPClient
    private let decoder = JSONDecoder()
    private let baseURL: URL

    init(baseURL: URL, session: any HTTPClient = URLSession.shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func loadUser(id: UUID) async throws -> User {
        let url = baseURL.appending(path: "users/\(id.uuidString)")
        let (data, response) = try await session.data(for: URLRequest(url: url))

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.badStatus(http.statusCode)
        }
        return try decoder.decode(User.self, from: data)
    }
}

// Migration strategy:
// 1. Add the async method beside the completion API; migrate one feature vertically.
// 2. Keep UI mutation in a @MainActor view model; networking picks no UI executor.
// 3. Delete the completion overload only after its call sites are gone.
//
// Production notes:
// - Cancellation propagates through URLSession.data(for:); do not swallow CancellationError.
// - Map HTTP status into domain errors at the repository boundary, never in SwiftUI views.
// - Retry only idempotent operations with bounded exponential backoff.
// - The tiny protocol makes deterministic transport injection easy in tests.
