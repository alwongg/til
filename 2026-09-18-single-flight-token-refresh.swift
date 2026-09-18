// Production Patterns at Scale: Single-Flight Token Refresh
//
// When several requests receive 401 together, I do not let each request refresh
// independently. This actor coalesces them onto one in-flight Task, preventing a
// refresh stampede and making the recovery path observable and testable.

import Foundation

struct AccessToken: Sendable, Equatable {
    let value: String
    let expiresAt: Date

    var isUsable: Bool {
        expiresAt > Date().addingTimeInterval(30)
    }
}

enum TokenError: Error {
    case missingRefreshCredential
}

actor TokenStore {
    private var cached: AccessToken?
    private var refreshTask: Task<AccessToken, Error>?
    private let refresh: @Sendable () async throws -> AccessToken

    init(refresh: @escaping @Sendable () async throws -> AccessToken) {
        self.refresh = refresh
    }

    func validToken() async throws -> AccessToken {
        if let cached, cached.isUsable {
            return cached
        }

        // Reuse the existing work so concurrent callers all await one refresh.
        if let refreshTask {
            return try await refreshTask.value
        }

        let task = Task { try await refresh() }
        refreshTask = task

        do {
            let token = try await task.value
            cached = token
            refreshTask = nil
            return token
        } catch {
            // Clear failures too; the next user action can attempt a fresh refresh.
            refreshTask = nil
            throw error
        }
    }

    func invalidate() {
        cached = nil
    }
}

// In production I inject `refresh` from the authenticated API client. Tests can
// provide a deterministic closure and assert that concurrent calls invoke it once.
