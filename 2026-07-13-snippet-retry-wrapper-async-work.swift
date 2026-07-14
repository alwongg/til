import Foundation

/*
I reach for a tiny retry wrapper when a dependency is flaky but the call site should stay readable.
The important part is not “retry everything” — it is encoding which failures are transient.
*/

struct RetryPolicy {
    let maxAttempts: Int
    let delayNanoseconds: UInt64
    let shouldRetry: @Sendable (Error) -> Bool
}

enum NetworkError: Error {
    case offline
    case server(statusCode: Int)
    case decoding
}

func retry<T>(policy: RetryPolicy, operation: @Sendable () async throws -> T) async throws -> T {
    precondition(policy.maxAttempts > 0, "Need at least one attempt")

    for attempt in 1...policy.maxAttempts {
        do {
            return try await operation()
        } catch {
            let isLastAttempt = attempt == policy.maxAttempts
            if isLastAttempt || !policy.shouldRetry(error) {
                throw error
            }

            // I keep the backoff policy explicit so product code can tune it per dependency.
            try await Task.sleep(nanoseconds: policy.delayNanoseconds * UInt64(attempt))
        }
    }

    fatalError("Unreachable: maxAttempts guarantees a return or throw")
}

actor FlakyProfileAPI {
    private var attempts = 0

    func fetchDisplayName() async throws -> String {
        attempts += 1
        if attempts < 3 { throw NetworkError.offline }
        return "Alex Wong"
    }
}

@main
enum Demo {
    static func main() async {
        let api = FlakyProfileAPI()
        let policy = RetryPolicy(
            maxAttempts: 3,
            delayNanoseconds: 150_000_000,
            shouldRetry: { error in
                switch error {
                case NetworkError.offline, NetworkError.server(statusCode: 502...599):
                    return true
                default:
                    return false
                }
            }
        )

        do {
            let name = try await retry(policy: policy) {
                try await api.fetchDisplayName()
            }
            print("Loaded profile for \(name)")
        } catch {
            print("Giving up after retry policy: \(error)")
        }
    }
}
