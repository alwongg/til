// Production Pattern: Idempotent Async Commands
//
// I treat a network mutation as a command with a stable idempotency key.
// Retries are then safe: a timeout can be retried without creating a second order.

import Foundation

struct IdempotencyKey: Hashable, Sendable {
    let rawValue: UUID

    init() { rawValue = UUID() }
}

struct Command<Response: Sendable>: Sendable {
    let key: IdempotencyKey
    let execute: @Sendable () async throws -> Response
}

actor CommandDeduplicator {
    private var completed: [IdempotencyKey: any Sendable] = [:]

    func run<Response: Sendable>(_ command: Command<Response>) async throws -> Response {
        // Cache only a completed response. A real API must also enforce this key server-side.
        if let cached = completed[command.key] as? Response {
            return cached
        }

        let response = try await command.execute()
        completed[command.key] = response
        return response
    }
}

enum RetryError: Error { case exhausted }

func retry<Response: Sendable>(
    attempts: Int = 3,
    operation: @escaping @Sendable () async throws -> Response
) async throws -> Response {
    precondition(attempts > 0)

    var lastError: Error?
    for attempt in 1...attempts {
        do { return try await operation() }
        catch {
            lastError = error
            // Exponential backoff contains transient failures without busy-waiting.
            try? await Task.sleep(for: .milliseconds(200 * (1 << (attempt - 1))))
        }
    }
    throw lastError ?? RetryError.exhausted
}

@main
struct Demo {
    static func main() async {
        let deduplicator = CommandDeduplicator()
        let command = Command(key: IdempotencyKey()) { "order-confirmed" }

        do {
            let first = try await deduplicator.run(command)
            let replay = try await deduplicator.run(command)
            print(first == replay) // true: one logical command, stable result
        } catch {
            print("Command failed: \(error)")
        }
    }
}

/*
Legacy approach
- A button directly calls a mutation endpoint; on a timeout I retry blindly.
- The client cannot distinguish “request failed” from “response was lost after success.”

Modern approach
- I create one idempotency key when the user starts the intent and send it with every retry.
- The server persists key -> result atomically and returns the original result on replay.
- Locally, an actor owns in-flight/completed command coordination rather than mutable dictionaries on views.

Migration strategy
1. Start with high-cost mutations: checkout, subscription changes, and uploads.
2. Add an Idempotency-Key header and server storage with an expiry appropriate to the business action.
3. Instrument duplicate replays and retry causes before enabling aggressive retries.

Production notes
- This sample's cache is process-local; it is not a substitute for server-side idempotency.
- Cache in-flight Tasks too when multiple screens can issue the same command concurrently.
- Retry only transient, explicitly classified failures; never retry validation or authorization errors.
*/
