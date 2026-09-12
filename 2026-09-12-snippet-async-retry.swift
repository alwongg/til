import Foundation

// I keep retry policy at the boundary so feature code stays focused on its job.
enum RetryFailure: Error {
    case exhaustedWithoutError
}

func retry<T: Sendable>(
    maxAttempts: Int = 3,
    initialDelayNanoseconds: UInt64 = 250_000_000,
    operation: @Sendable () async throws -> T
) async throws -> T {
    precondition(maxAttempts > 0, "Retrying zero times hides a programming error")

    var lastError: (any Error)?

    for attempt in 0..<maxAttempts {
        do {
            return try await operation()
        } catch is CancellationError {
            // Cancellation is intent, not a transient network failure.
            throw CancellationError()
        } catch {
            lastError = error

            guard attempt < maxAttempts - 1 else { break }

            // Exponential backoff limits pressure on a degraded dependency.
            let delay = initialDelayNanoseconds * UInt64(1 << attempt)
            try await Task.sleep(nanoseconds: delay)
        }
    }

    throw lastError ?? RetryFailure.exhaustedWithoutError
}
