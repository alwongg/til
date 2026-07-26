import Foundation

/// Retries only transient work and preserves the final error for the caller.
func retry<Value>(
    attempts: Int = 3,
    initialDelayNanoseconds: UInt64 = 250_000_000,
    operation: @escaping () async throws -> Value
) async throws -> Value {
    precondition(attempts > 0, "At least one attempt is required")

    var delay = initialDelayNanoseconds
    var lastError: Error?

    for attempt in 1...attempts {
        do {
            return try await operation()
        } catch {
            lastError = error
            guard attempt < attempts else { break }

            // Backoff gives a recovering network/service room before retrying.
            try await Task.sleep(nanoseconds: delay)
            delay *= 2
        }
    }

    throw lastError!
}

struct ProfileService {
    func loadProfile() async throws -> String {
        try await retry { "Alex" }
    }
}
