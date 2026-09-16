// Swift Snippet: Retry async work without retrying the wrong failures
//
// I keep retries at the transport boundary. A retry can hide a transient network
// failure, but retrying validation or decoding errors only delays a useful failure.

import Foundation

enum RetryError: Error {
    case exhausted(lastError: Error)
}

func retrying<T>(
    attempts: Int = 3,
    initialDelay: Duration = .milliseconds(250),
    shouldRetry: @escaping (Error) -> Bool,
    operation: @escaping () async throws -> T
) async throws -> T {
    precondition(attempts > 0)

    var delay = initialDelay
    var lastError: Error?

    for attempt in 1...attempts {
        do {
            return try await operation()
        } catch {
            lastError = error
            guard attempt < attempts, shouldRetry(error) else { throw error }

            // Backing off keeps a recovering service from receiving another burst.
            try await Task.sleep(for: delay)
            delay *= 2
        }
    }

    throw RetryError.exhausted(lastError: lastError!)
}

func isTransient(_ error: Error) -> Bool {
    guard let urlError = error as? URLError else { return false }
    return [URLError.timedOut, .networkConnectionLost, .notConnectedToInternet]
        .contains(urlError.code)
}
