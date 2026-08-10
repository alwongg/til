import Foundation

struct RetryPolicy {
    let maxAttempts: Int
    let initialDelay: Duration

    func run<T: Sendable>(
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        precondition(maxAttempts > 0)

        var delay = initialDelay
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                guard attempt < maxAttempts else { throw error }

                // Back off between attempts so a transient outage is not amplified.
                try await Task.sleep(for: delay)
                delay *= 2
            }
        }
        fatalError("The loop either returns or throws")
    }
}

@main
struct RetryExample {
    static func main() async {
        let policy = RetryPolicy(maxAttempts: 3, initialDelay: .milliseconds(250))
        do {
            let value: String = try await policy.run {
                try await fetchRemoteValue()
            }
            print(value)
        } catch {
            print("Request failed after retries: \(error)")
        }
    }

    static func fetchRemoteValue() async throws -> String { "Loaded" }
}
