import Foundation

protocol RetryStrategy: Sendable {
    func delay(after attempt: Int, error: Error) -> Duration?
}

struct NoRetry: RetryStrategy {
    func delay(after attempt: Int, error: Error) -> Duration? { nil }
}

struct ExponentialBackoff: RetryStrategy {
    let maximumAttempts: Int

    func delay(after attempt: Int, error: Error) -> Duration? {
        guard attempt < maximumAttempts else { return nil }
        // Cap the wait so a degraded service does not trap the UI forever.
        let seconds = min(1 << attempt, 8)
        return .seconds(seconds)
    }
}

enum Endpoint {
    case profile
    case timeline

    var retryStrategy: any RetryStrategy {
        switch self {
        case .profile: NoRetry() // Avoid replaying sensitive writes.
        case .timeline: ExponentialBackoff(maximumAttempts: 3)
        }
    }
}

func retryDelay(for endpoint: Endpoint, attempt: Int, error: Error) -> Duration? {
    endpoint.retryStrategy.delay(after: attempt, error: error)
}
