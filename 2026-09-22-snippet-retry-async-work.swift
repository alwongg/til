// Swift Snippet — Retry async work without hiding cancellation
//
// I keep retry policy at the call site instead of burying it in a networking
// client. That makes the number of attempts and backoff explicit per use case.

import Foundation

enum RetryError: Error {
    case exhausted
}

func retry<T>(
    attempts: Int = 3,
    delayNanoseconds: UInt64 = 300_000_000,
    operation: @escaping () async throws -> T
) async throws -> T {
    precondition(attempts > 0)

    var lastError: Error?
    for attempt in 1...attempts {
        do {
            return try await operation()
        } catch is CancellationError {
            // Cancellation is intent, not a transient failure.
            throw CancellationError()
        } catch {
            lastError = error
            guard attempt < attempts else { break }
            try await Task.sleep(nanoseconds: delayNanoseconds * UInt64(attempt))
        }
    }
    throw lastError ?? RetryError.exhausted
}

@main
struct RetryDemo {
    static func main() async {
        let value = try? await retry { "loaded" }
        print(value ?? "failed")
    }
}
