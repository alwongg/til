import Foundation

// I centralize retries so feature code states its intent once, rather than
// duplicating backoff loops with subtly different cancellation behavior.
enum RetryError: Error {
    case exhausted(lastError: Error)
}

func retry<T: Sendable>(
    attempts: Int = 3,
    initialDelayNanoseconds: UInt64 = 250_000_000,
    operation: @Sendable () async throws -> T
) async throws -> T {
    precondition(attempts > 0)

    var delay = initialDelayNanoseconds
    var lastError: Error?

    for attempt in 1...attempts {
        do {
            return try await operation()
        } catch is CancellationError {
            // Cancellation is control flow; retrying it makes dismissal feel broken.
            throw CancellationError()
        } catch {
            lastError = error
            guard attempt < attempts else { break }
            try await Task.sleep(nanoseconds: delay)
            delay *= 2
        }
    }

    throw RetryError.exhausted(lastError: lastError!)
}

struct Profile: Decodable, Sendable { let name: String }

// The caller owns the endpoint; this helper owns the retry policy.
func loadProfile(
    fetch: @Sendable () async throws -> Profile
) async throws -> Profile {
    try await retry(operation: fetch)
}
