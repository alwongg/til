// Swift Snippet: Cancellation-Aware Retry
//
// I keep retry policy at the boundary of flaky work rather than scattering
// loops through call sites. Cancellation is not a transient failure: if a view
// disappears, this exits immediately instead of making the user wait.

import Foundation

func retry<T: Sendable>(
    attempts: Int = 3,
    baseDelayNanoseconds: UInt64 = 500_000_000,
    operation: @Sendable () async throws -> T
) async throws -> T {
    precondition(attempts > 0, "A retry policy needs at least one attempt")

    for attempt in 0..<attempts {
        do {
            return try await operation()
        } catch is CancellationError {
            // Propagating cancellation preserves structured-concurrency intent.
            throw CancellationError()
        } catch {
            guard attempt < attempts - 1 else { throw error }

            // Exponential backoff avoids immediately amplifying a transient outage.
            let multiplier = UInt64(1) << UInt64(min(attempt, 20))
            try await Task.sleep(nanoseconds: baseDelayNanoseconds * multiplier)
        }
    }

    fatalError("The loop either returns or throws on its final attempt")
}

// I can inject a URLSession request, database read, or service call as `operation`.
