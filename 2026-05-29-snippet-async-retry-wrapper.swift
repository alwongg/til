import Foundation

struct RetryPolicy {
    let maxAttempts: Int
    let delayNanoseconds: UInt64
}

enum DemoError: Error {
    case transientFailure(attempt: Int)
}

func retry<T>(policy: RetryPolicy, operation: @escaping @Sendable () async throws -> T) async throws -> T {
    precondition(policy.maxAttempts > 0, "maxAttempts must be at least 1")

    var lastError: Error?

    for attempt in 1...policy.maxAttempts {
        do {
            return try await operation()
        } catch {
            lastError = error

            guard attempt < policy.maxAttempts else { break }
            // I keep retry timing in one place so call sites stay focused on product logic.
            try await Task.sleep(nanoseconds: policy.delayNanoseconds)
        }
    }

    throw lastError ?? DemoError.transientFailure(attempt: policy.maxAttempts)
}

actor FlakyService {
    private var attemptCount = 0

    func loadProfile() async throws -> String {
        attemptCount += 1

        guard attemptCount >= 3 else {
            throw DemoError.transientFailure(attempt: attemptCount)
        }

        return "Profile loaded on attempt \(attemptCount)"
    }
}

@main
struct DemoApp {
    static func main() async {
        let service = FlakyService()
        let policy = RetryPolicy(maxAttempts: 4, delayNanoseconds: 300_000_000)

        do {
            let result = try await retry(policy: policy) {
                try await service.loadProfile()
            }
            print(result)
        } catch {
            // The point is not retrying forever. The point is making failure predictable.
            print("Load failed: \(error)")
        }
    }
}
