import Foundation

/*
 Production Patterns at Scale: Make Retry Policy Explicit

 I treat retries as product behaviour, not a networking afterthought. A refresh
 gesture deserves a different recovery budget from a background sync, and neither
 should quietly retry an authentication failure.

 Legacy approach
 My older call sites mixed retry loops into each repository. That made
 cancellation, backoff, and error classification inconsistent—and multiplying a
 transient outage across screens was easy.

 Modern approach
 I put the policy at the boundary. The executor owns when another attempt is
 reasonable; the repository still owns which failures are retryable. The
 operation is @Sendable, so it remains safe to use from structured concurrency.
*/

struct RetryPolicy: Sendable {
    let maxAttempts: Int
    let initialDelay: Duration
    let multiplier: Double

    static let foreground = RetryPolicy(
        maxAttempts: 3,
        initialDelay: .milliseconds(250),
        multiplier: 2
    )
}

enum RequestFailure: Error, Sendable {
    case unauthenticated
    case server(statusCode: Int)
    case transport

    var isRetryable: Bool {
        switch self {
        case .transport, .server(500...599): return true
        case .unauthenticated, .server: return false
        }
    }
}

struct RequestExecutor: Sendable {
    let policy: RetryPolicy

    func run<Value: Sendable>(
        operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        var delay = policy.initialDelay

        for attempt in 1...policy.maxAttempts {
            do {
                return try await operation()
            } catch is CancellationError {
                throw CancellationError() // A cancelled screen must stop immediately.
            } catch let failure as RequestFailure
                where failure.isRetryable && attempt < policy.maxAttempts {
                try await Task.sleep(for: delay)
                let milliseconds = Double(delay.components.seconds) * 1_000
                    + Double(delay.components.attoseconds) / 1e15
                delay = .milliseconds(Int(milliseconds * policy.multiplier))
            } catch {
                throw error
            }
        }
        fatalError("The loop either returns or throws before this point")
    }
}

/*
 Migration strategy
 I start with one idempotent read endpoint, inject RequestExecutor into that
 repository, then add telemetry for attempt count and final error. Only after the
 numbers justify it do I give writes an idempotency key and the same policy.

 Production notes
 - I retry transport failures and 5xx responses, never 401/403 or ordinary 4xx.
 - I preserve cancellation: waiting for a retry must not keep a dismissed view alive.
 - In a real client I add jitter and a cap; synchronized retries extend outages.
 - I log retry count separately from request count, so reliability work has an honest signal.
*/
