import Foundation

// 2026-05-25 — Swift Language Evolution
// Title: From Escaping Closures to async/await
//
// I still run into older networking layers built around completion handlers.
// They work, but the call sites tend to hide intent, duplicate error handling,
// and make cancellation feel bolted on. This is the transformation I reach for.

struct User: Decodable {
    let id: Int
    let name: String
}

enum NetworkError: Error {
    case badStatusCode(Int)
    case missingData
}

// Legacy approach: escaping closures push control flow outward.
func loadUserLegacy(id: Int, completion: @escaping (Result<User, Error>) -> Void) {
    let url = URL(string: "https://example.com/users/\(id)")!
    URLSession.shared.dataTask(with: url) { data, response, error in
        if let error {
            completion(.failure(error))
            return
        }

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(statusCode) else {
            completion(.failure(NetworkError.badStatusCode(statusCode)))
            return
        }

        guard let data else {
            completion(.failure(NetworkError.missingData))
            return
        }

        do {
            completion(.success(try JSONDecoder().decode(User.self, from: data)))
        } catch {
            completion(.failure(error))
        }
    }.resume()
}

// Modern approach: async/await keeps the happy path linear and readable.
func loadUser(id: Int) async throws -> User {
    let url = URL(string: "https://example.com/users/\(id)")!
    let (data, response) = try await URLSession.shared.data(from: url)

    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
    guard (200...299).contains(statusCode) else {
        throw NetworkError.badStatusCode(statusCode)
    }

    return try JSONDecoder().decode(User.self, from: data)
}

// Migration strategy:
// 1. Keep the old API temporarily for callers you can't move yet.
// 2. Build the async function as the source of truth.
// 3. Bridge backward only at the edges, not throughout the codebase.
func loadUserBridged(id: Int, completion: @escaping (Result<User, Error>) -> Void) {
    Task {
        do {
            completion(.success(try await loadUser(id: id)))
        } catch {
            completion(.failure(error))
        }
    }
}

// Production notes:
// - Cancellation now flows naturally when the parent task is cancelled.
// - Call sites can compose retries, timeouts, and task groups without nesting.
// - I still keep domain-specific errors so logs stay actionable in production.

@main
struct DemoApp {
    static func main() async {
        do {
            let user = try await loadUser(id: 42)
            print("Loaded user: \(user.name)")
        } catch {
            print("Request failed: \(error)")
        }
    }
}
