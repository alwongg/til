// 2026-07-02 Snippet — Retry wrapper for async throwing work
//
// I like keeping retry logic at the edge instead of scattering loops around every call site.
// This version makes the retry policy explicit: attempts, delay, and whether an error is retryable.
// The result is easier to test and safer to reuse across API, disk, or cache refresh work.

import Foundation

enum RetryError: Error {
    case exhausted(lastError: Error)
}

func retry<T>(
    attempts: Int,
    delayNanoseconds: UInt64,
    shouldRetry: (Error) -> Bool = { _ in true },
    operation: () async throws -> T
) async throws -> T {
    precondition(attempts > 0, "attempts must be at least 1")

    var lastError: Error?

    for attempt in 1...attempts {
        do {
            return try await operation()
        } catch {
            lastError = error
            guard attempt < attempts, shouldRetry(error) else { break }
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
    }

    throw RetryError.exhausted(lastError: lastError ?? CancellationError())
}

@main
struct Demo {
    static func main() async {
        var tries = 0

        do {
            let value = try await retry(attempts: 3, delayNanoseconds: 200_000_000) {
                tries += 1
                if tries < 3 { throw URLError(.timedOut) }
                return "Loaded on attempt \(tries)"
            }
            print(value)
        } catch {
            print("Retry failed: \(error)")
        }
    }
}
