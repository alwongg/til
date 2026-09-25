# Production Patterns at Scale: Put Retry Policy at the Transport Boundary

At scale, I do not scatter retry loops through view models. A view model should decide what the UI does; the transport layer should decide whether a failed request is worth another attempt.

## Legacy approach

```swift
// Each caller invents its own delay, retry count, and cancellation behaviour.
for attempt in 0..<3 {
    do { return try await client.loadProfile() }
    catch { try? await Task.sleep(for: .seconds(1)) }
}
```

This duplicates policy, often retries non-retryable 4xx responses, and can accidentally swallow cancellation.

## Modern approach

```swift
import Foundation

struct HTTPStatusError: Error {
    let statusCode: Int
}

struct RetryPolicy: Sendable {
    let maxAttempts: Int
    let baseDelay: Duration

    func shouldRetry(_ error: Error, attempt: Int) -> Bool {
        guard attempt < maxAttempts else { return false }
        if let status = error as? HTTPStatusError {
            return status.statusCode == 429 || (500...599).contains(status.statusCode)
        }
        return error is URLError
    }

    func delay(for attempt: Int) -> Duration {
        baseDelay * pow(2.0, Double(attempt - 1))
    }
}

actor RetryingTransport {
    private let policy: RetryPolicy

    init(policy: RetryPolicy = .init(maxAttempts: 3, baseDelay: .milliseconds(250))) {
        self.policy = policy
    }

    func perform<T: Sendable>(_ operation: @Sendable () async throws -> T) async throws -> T {
        var attempt = 1
        while true {
            do {
                return try await operation()
            } catch is CancellationError {
                throw CancellationError() // Cancellation is control flow, never a transient error.
            } catch {
                guard policy.shouldRetry(error, attempt: attempt) else { throw error }
                try await Task.sleep(for: policy.delay(for: attempt))
                attempt += 1
            }
        }
    }
}
```

## Migration strategy

1. Add the transport wrapper beside the existing client; do not rewrite feature code first.
2. Route one idempotent GET endpoint through it and record attempts, status codes, and final outcome.
3. Expand only after defining endpoint-specific rules. Mutations need idempotency keys or no automatic retry.

## Production notes

- Retry only errors I can defend: throttling, server failures, and selected connectivity errors.
- Bound attempts and use exponential backoff so an outage does not become a client-side traffic spike.
- Keep policy injectable: tests can use zero delay and assert exact attempt counts.
- Measure retry success separately from request success; a rising retry rate is an early reliability signal.
