import Foundation

/*
# Swift Language Evolution — migrating completion handlers to structured concurrency

I still run into older service layers that expose completion handlers everywhere. They work,
but the calling code usually leaks state management into view models and makes cancellation
feel bolted on. My current migration path is to keep the transport small, move orchestration
into an actor, and return async values instead of nested callbacks.

## Legacy approach
- completion handlers fan out error handling across multiple closures
- duplicate refresh logic races when several requests fail together
- cancellation is weak because the API surface is not task-aware

## Modern approach
I wrap token coordination in an actor, expose async APIs, and let the caller decide whether
to await once, run work in parallel, or cancel upstream.
*/

struct User: Codable, Sendable {
    let id: UUID
    let name: String
}

enum APIError: Error, Sendable {
    case invalidResponse
    case unauthorized
}

protocol HTTPSession: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

struct URLSessionAdapter: HTTPSession {
    let session: URLSession = .shared

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}

actor AuthManager {
    private var cachedToken: String?
    private var refreshTask: Task<String, Error>?

    func validToken(using session: HTTPSession) async throws -> String {
        if let cachedToken {
            return cachedToken
        }

        if let refreshTask {
            return try await refreshTask.value
        }

        let task = Task<String, Error> {
            // In production I hide refresh details behind a dedicated endpoint client.
            try await Task.sleep(for: .milliseconds(50))
            return "fresh-token"
        }

        refreshTask = task
        defer { refreshTask = nil }

        let token = try await task.value
        cachedToken = token
        return token
    }

    func clearToken() {
        cachedToken = nil
    }
}

struct UserAPI {
    let session: HTTPSession
    let authManager: AuthManager
    let decoder = JSONDecoder()

    func fetchUser(id: UUID) async throws -> User {
        var request = URLRequest(url: URL(string: "https://example.com/users/\(id.uuidString)")!)
        request.setValue("Bearer \(try await authManager.validToken(using: session))", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch http.statusCode {
        case 200:
            return try decoder.decode(User.self, from: data)
        case 401:
            await authManager.clearToken()
            throw APIError.unauthorized
        default:
            throw APIError.invalidResponse
        }
    }
}

/*
## Migration strategy
1. Keep the old completion-based endpoint alive behind an adapter.
2. Introduce async entry points at the repository boundary first.
3. Move shared mutable auth state into an actor before enabling more parallel calls.
4. Convert the highest-churn screens first so cancellation starts paying for the refactor.

## Production notes
- Actors solve the "double refresh" problem without adding locking code.
- `Sendable` pressure is useful: it forces me to notice hidden shared state early.
- I treat `Task` ownership as part of the API design, especially in SwiftUI view models.
- This pattern gets stronger when paired with `AsyncSequence` for streaming updates later.
*/
