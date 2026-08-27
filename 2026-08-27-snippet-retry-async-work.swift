// Swift Snippet: Retry async work without hiding cancellation
//
// I retry transient failures at the boundary where I know the operation is
// idempotent. The policy keeps backoff visible and never turns cancellation
// into another network retry.

import Foundation

struct RetryPolicy: Sendable {
    let maxAttempts: Int
    let initialDelay: Duration

    func run<Value: Sendable>(
        operation: @Sendable () async throws -> Value,
        shouldRetry: @Sendable (Error) -> Bool
    ) async throws -> Value {
        precondition(maxAttempts > 0)

        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                guard attempt < maxAttempts, shouldRetry(error) else { throw error }

                // Exponential delay avoids immediately adding load to a service
                // that is already telling me it is unhealthy.
                let delay = initialDelay * (1 << (attempt - 1))
                try await Task.sleep(for: delay)
            }
        }

        fatalError("The loop either returns or throws")
    }
}

enum NetworkFailure: Error { case offline, unauthorized }

let retryablePolicy = RetryPolicy(maxAttempts: 3, initialDelay: .milliseconds(250))
// Use this only for idempotent operations, e.g. a GET request:
// let profile = try await retryablePolicy.run(operation: loadProfile) { error in
//     error as? NetworkFailure == .offline
// }
