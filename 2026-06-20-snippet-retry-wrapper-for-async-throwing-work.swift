import Foundation

struct RetryPolicy {
    let maxAttempts: Int
    let initialDelayNanoseconds: UInt64
    let backoffMultiplier: Double

    func delay(for attempt: Int) -> UInt64 {
        let scaled = Double(initialDelayNanoseconds) * pow(backoffMultiplier, Double(attempt - 1))
        return UInt64(scaled.rounded())
    }
}

enum RetryDecision {
    case retry
    case fail
}

func retrying<T>(
    policy: RetryPolicy,
    operation: @escaping () async throws -> T,
    shouldRetry: @escaping (Error) -> RetryDecision
) async throws -> T {
    precondition(policy.maxAttempts > 0, "Retry policy must allow at least one attempt")

    var lastError: Error?

    for attempt in 1...policy.maxAttempts {
        do {
            return try await operation()
        } catch {
            lastError = error

            guard attempt < policy.maxAttempts else { break }
            guard shouldRetry(error) == .retry else { throw error }

            // I keep the backoff policy explicit so rate-limit handling is easy to tune per API.
            try await Task.sleep(nanoseconds: policy.delay(for: attempt))
        }
    }

    throw lastError ?? CancellationError()
}

struct TransientAPIError: Error {
    let statusCode: Int
}

func loadProfile() async throws -> String {
    let policy = RetryPolicy(maxAttempts: 3, initialDelayNanoseconds: 300_000_000, backoffMultiplier: 2)

    return try await retrying(policy: policy) {
        throw TransientAPIError(statusCode: 503)
    } shouldRetry: { error in
        guard let error = error as? TransientAPIError else { return .fail }
        return (500...599).contains(error.statusCode) ? .retry : .fail
    }
}
