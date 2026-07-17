// # Production Patterns at Scale: Coalescing Duplicate Requests
//
// At scale, the same screen can trigger identical requests from refreshes, retries,
// and multiple observers. I want one in-flight task per resource, not a thundering herd.

import Foundation

struct User: Decodable, Sendable {
    let id: Int
    let name: String
}

protocol UserLoading: Sendable {
    func user(id: Int) async throws -> User
}

// MARK: - Legacy approach

final class LegacyUserLoader: UserLoading, @unchecked Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func user(id: Int) async throws -> User {
        // Every caller creates another network request, even for the same user.
        let url = URL(string: "https://jsonplaceholder.typicode.com/users/\(id)")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(User.self, from: data)
    }
}

// MARK: - Modern approach

actor CoalescingUserLoader: UserLoading {
    private let session: URLSession
    private var inFlight: [Int: Task<User, Error>] = [:]

    init(session: URLSession = .shared) {
        self.session = session
    }

    func user(id: Int) async throws -> User {
        if let existing = inFlight[id] {
            return try await existing.value
        }

        let session = self.session
        let task = Task<User, Error> {
            let url = URL(string: "https://jsonplaceholder.typicode.com/users/\(id)")!
            let (data, response) = try await session.data(from: url)

            guard let http = response as? HTTPURLResponse,
                  200..<300 ~= http.statusCode else {
                throw URLError(.badServerResponse)
            }

            return try JSONDecoder().decode(User.self, from: data)
        }

        inFlight[id] = task

        // Cleanup must happen on success, decoding failure, cancellation, or HTTP error.
        defer { inFlight[id] = nil }
        return try await task.value
    }
}

// MARK: - Migration strategy

// 1. Keep the UserLoading protocol stable so call sites do not change.
// 2. Inject CoalescingUserLoader behind one feature flag or composition root.
// 3. Compare request count, latency, and error rate before broad rollout.
// 4. Add a separate TTL cache only after coalescing is proven; they solve different problems.

// MARK: - Production notes

// - Actor isolation makes lookup and insertion atomic across concurrent callers.
// - The dictionary stores Tasks, so every waiter receives the same value or error.
// - A cancelled waiter does not automatically cancel shared work for other waiters.
// - Key by the full request identity in real clients: endpoint, auth scope, locale, and query.
// - Bound cardinality and instrument coalesced-hit rate; invisible optimizations regress easily.

@main
enum Demo {
    static func main() async {
        let loader = CoalescingUserLoader()

        do {
            async let first = loader.user(id: 1)
            async let second = loader.user(id: 1)
            let users = try await [first, second]
            print(users.map(\.name))
        } catch {
            print("Request failed: \(error)")
        }
    }
}
