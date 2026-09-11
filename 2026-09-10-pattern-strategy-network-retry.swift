// # Strategy Pattern: Retry Policies Without `if` Ladders
//
// I keep retry policy separate from request execution. That makes product-specific
// choices—fast retries for a tap, slower retries for a background sync—easy to
// test and change without turning my networking layer into a conditional maze.

import Foundation

protocol RetryStrategy: Sendable {
    /// `attempt` is the failed attempt number, starting at 1.
    func delayNanoseconds(afterFailedAttempt attempt: Int) -> UInt64?
}

struct ExponentialBackoff: RetryStrategy {
    let maxRetries: Int
    let initialDelay: UInt64

    func delayNanoseconds(afterFailedAttempt attempt: Int) -> UInt64? {
        guard attempt <= maxRetries else { return nil }
        return initialDelay * (1 << UInt64(attempt - 1))
    }
}

struct RequestRetrier: Sendable {
    let strategy: any RetryStrategy

    func run<Value: Sendable>(
        _ operation: @Sendable () async throws -> Value
    ) async throws -> Value {
        var failedAttempts = 0

        while true {
            do {
                return try await operation()
            } catch {
                failedAttempts += 1
                guard let delay = strategy.delayNanoseconds(
                    afterFailedAttempt: failedAttempts
                ) else {
                    throw error
                }
                // Sleeping here keeps the policy reusable; callers own cancellation.
                try await Task.sleep(nanoseconds: delay)
            }
        }
    }
}

// I can inject `ExponentialBackoff(maxRetries: 2, initialDelay: 250_000_000)`
// for a user-initiated request, or provide a different strategy for sync work.
// In production I would also restrict retries to transient errors, add jitter,
// and capture each final failure in my observability pipeline.
