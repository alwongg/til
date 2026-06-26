import Foundation

func retrying<T>(
    maxAttempts: Int,
    initialDelayNanoseconds: UInt64 = 200_000_000,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    precondition(maxAttempts > 0, "I never want a retry helper that silently does nothing.")

    var attempt = 1
    var delay = initialDelayNanoseconds

    while true {
        do {
            return try await operation()
        } catch {
            guard attempt < maxAttempts else { throw error }
            // I keep the backoff policy here so call sites stay focused on intent.
            try await Task.sleep(nanoseconds: delay)
            attempt += 1
            delay *= 2
        }
    }
}

actor FlakyProfileAPI {
    private var remainingFailures = 2

    func fetchProfile() async throws -> String {
        guard remainingFailures > 0 else { return "Profile loaded" }
        remainingFailures -= 1
        throw URLError(.networkConnectionLost)
    }
}

@main
enum Demo {
    static func main() async {
        let api = FlakyProfileAPI()

        do {
            let profile = try await retrying(maxAttempts: 3) {
                try await api.fetchProfile()
            }
            print(profile)
        } catch {
            print("Final failure: \(error)")
        }
    }
}
