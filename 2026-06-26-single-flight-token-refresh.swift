import Foundation

/*:
# Production Patterns at Scale: Single-Flight Token Refresh

I don't treat auth refresh as a networking detail anymore. In production, the real bug is stampeding refresh traffic: five requests hit a 401, five refresh calls race, one wins, and the other four leave the app in an undefined state.

## Legacy approach
I used to let each API call decide when to refresh. That looked simple, but it multiplied work, created retry storms, and made logs impossible to reason about under load.

## Modern approach
I now centralize refresh behind an actor and make every caller await the same in-flight task. The pattern is single-flight refresh: one refresh starts, everyone else joins it, and the coordinator clears itself when the work finishes.

## Migration strategy
1. Keep the existing `TokenStore` and API client surface.
2. Move refresh orchestration into one actor.
3. Route every 401 through the coordinator instead of refreshing inline.
4. Add metrics for refresh count, retry count, and repeated 401s after refresh.

## Production notes
- I cap retries to one refresh pass per request. Infinite auth retries hide backend incidents.
- I keep the actor small and side-effect aware: token persistence stays explicit.
- I log refresh start/success/failure separately so I can spot token churn before users feel it.
*/

protocol TokenStore: Sendable {
    func read() async -> String?
    func write(_ token: String) async
}

actor InMemoryTokenStore: TokenStore {
    private var token: String?

    init(token: String? = nil) {
        self.token = token
    }

    func read() async -> String? { token }
    func write(_ token: String) async { self.token = token }
}

struct AuthService: Sendable {
    let refresh: @Sendable () async throws -> String
}

actor TokenRefreshCoordinator {
    private let authService: AuthService
    private let tokenStore: TokenStore
    private var inFlightRefresh: Task<String, Error>?

    init(authService: AuthService, tokenStore: TokenStore) {
        self.authService = authService
        self.tokenStore = tokenStore
    }

    func validToken() async throws -> String {
        if let token = await tokenStore.read() {
            return token
        }
        return try await refreshToken()
    }

    func refreshToken() async throws -> String {
        if let inFlightRefresh {
            return try await inFlightRefresh.value
        }

        let task = Task { () throws -> String in
            let newToken = try await authService.refresh()
            await tokenStore.write(newToken)
            return newToken
        }

        inFlightRefresh = task
        defer { inFlightRefresh = nil }
        return try await task.value
    }
}

struct RequestExecutor {
    let coordinator: TokenRefreshCoordinator
    let performRequest: @Sendable (_ token: String) async throws -> Int

    func responseCode() async throws -> Int {
        let firstToken = try await coordinator.validToken()
        let firstAttempt = try await performRequest(firstToken)
        guard firstAttempt == 401 else {
            return firstAttempt
        }

        let refreshedToken = try await coordinator.refreshToken()
        return try await performRequest(refreshedToken)
    }
}

@main
struct DemoApp {
    static func main() async {
        let tokenStore = InMemoryTokenStore(token: "expired-token")
        let authService = AuthService(refresh: {
            try await Task.sleep(nanoseconds: 50_000_000)
            return "fresh-token"
        })

        let coordinator = TokenRefreshCoordinator(authService: authService, tokenStore: tokenStore)
        let executor = RequestExecutor(
            coordinator: coordinator,
            performRequest: { token in
                token == "fresh-token" ? 200 : 401
            }
        )

        do {
            let codes = try await withThrowingTaskGroup(of: Int.self) { group in
                for _ in 0..<3 {
                    group.addTask { try await executor.responseCode() }
                }

                var results: [Int] = []
                for try await code in group {
                    results.append(code)
                }
                return results.sorted()
            }

            print("Response codes: \(codes)")
        } catch {
            print("Refresh flow failed: \(error)")
        }
    }
}
