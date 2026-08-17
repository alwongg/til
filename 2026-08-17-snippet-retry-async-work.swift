// RetryAsync.swift
// I keep retries at the transport boundary so view models don't quietly own
// backoff policy. Cancellation is never retried: it means the caller is done.

import Foundation

struct RetryPolicy: Sendable {
    let maxAttempts: Int
    let initialDelay: Duration

    func run<T: Sendable>(
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        precondition(maxAttempts > 0)

        var delay = initialDelay
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                guard attempt < maxAttempts else { throw error }
                try await Task.sleep(for: delay)
                delay *= 2
            }
        }
        fatalError("The loop always returns or throws")
    }
}

// Usage: let value = try await RetryPolicy(maxAttempts: 3, initialDelay: .seconds(1)).run {
//     try await apiClient.fetchProfile()
// }
