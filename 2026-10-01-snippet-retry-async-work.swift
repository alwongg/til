// Swift Snippet: Retry async work without hiding the failure
//
// I keep retries at the boundary where a transient failure is meaningful.
// A repository can opt in, while a decoding or validation error still escapes
// immediately after its configured attempts.

import Foundation

enum RetryError: Error {
    case exhausted(attempts: Int, underlying: Error)
}

func retry<Value>(
    attempts: Int = 3,
    delayNanoseconds: UInt64 = 250_000_000,
    operation: @Sendable () async throws -> Value
) async throws -> Value {
    precondition(attempts > 0, "A retry policy needs at least one attempt")

    var lastError: Error?

    for attempt in 1...attempts {
        do {
            return try await operation()
        } catch is CancellationError {
            // I never turn cancellation into background work that keeps running.
            throw CancellationError()
        } catch {
            lastError = error
            guard attempt < attempts else { break }
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
    }

    throw RetryError.exhausted(attempts: attempts, underlying: lastError!)
}

// Usage: let profile = try await retry { try await api.fetchProfile() }
