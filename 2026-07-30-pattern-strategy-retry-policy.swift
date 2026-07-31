/*
 # Strategy Pattern: Keep Retry Decisions Out of Networking

 I use a strategy when the operation stays the same but a policy needs to vary. A client should know how to send a request; it should not accumulate `if isReachable`, `if isDebug`, and endpoint-specific retry rules.

 The protocol makes retry policy injectable and easy to test. My production version adds jitter and honours `Retry-After`, but the boundary stays the same.
*/

import Foundation

protocol RetryStrategy: Sendable {
    func delay(after error: Error, attempt: Int) -> Duration?
}

struct ExponentialBackoff: RetryStrategy {
    let maximumAttempts: Int

    func delay(after error: Error, attempt: Int) -> Duration? {
        guard attempt < maximumAttempts else { return nil }
        // Keeping policy here lets the transport remain focused on one request.
        return .seconds(pow(2.0, Double(attempt - 1)))
    }
}

struct NoRetry: RetryStrategy {
    func delay(after error: Error, attempt: Int) -> Duration? { nil }
}

func perform<T: Sendable>(
    using strategy: some RetryStrategy,
    operation: @Sendable () async throws -> T
) async throws -> T {
    var attempt = 1
    while true {
        do { return try await operation() }
        catch {
            guard let delay = strategy.delay(after: error, attempt: attempt) else { throw error }
            attempt += 1
            try await Task.sleep(for: delay)
        }
    }
}

/*
 ## Production notes
 - Retry only idempotent work unless the server supplies an idempotency key.
 - Model retryable HTTP status codes separately from decoding and auth failures.
 - Inject `NoRetry()` in focused tests; it makes failure timing deterministic.
*/
