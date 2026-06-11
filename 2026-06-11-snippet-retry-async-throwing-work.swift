import Foundation

struct RetryPolicy {
    let maxAttempts: Int
    let delayNanoseconds: UInt64
}

enum RetryError: Error {
    case exhausted(lastError: Error)
}

func retrying<T>(policy: RetryPolicy, operation: @escaping () async throws -> T) async throws -> T {
    precondition(policy.maxAttempts > 0, "maxAttempts must be positive")

    var lastError: Error?

    for attempt in 1...policy.maxAttempts {
        do {
            return try await operation()
        } catch {
            lastError = error
            guard attempt < policy.maxAttempts else { break }
            // I back off between attempts so transient failures do not immediately cascade into user-facing errors.
            try await Task.sleep(nanoseconds: policy.delayNanoseconds * UInt64(attempt))
        }
    }

    throw RetryError.exhausted(lastError: lastError!)
}

@main
enum RetryWrapperSnippet {
    static func main() async {
        let policy = RetryPolicy(maxAttempts: 3, delayNanoseconds: 150_000_000)
        var attempts = 0

        do {
            let value: String = try await retrying(policy: policy) {
                attempts += 1
                if attempts < 3 { throw URLError(.networkConnectionLost) }
                return "Loaded after \(attempts) attempts"
            }
            print(value)
        } catch {
            print("Retry failed:", error)
        }
    }
}
