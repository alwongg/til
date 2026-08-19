// AI Integration in iOS: Turn Model Callbacks into a Cancellable Async Stream
//
// My legacy integration exposed a completion closure. It made partial tokens,
// cancellation, and errors compete for one terminal callback, then forced the
// ViewModel to own lifecycle bookkeeping.
//
// Modern approach: I expose model output as AsyncThrowingStream. The UI consumes
// one vocabulary (`for try await`), cancellation propagates through the stream,
// and the adapter remains the only place that knows the vendor callback shape.
//
// Migration strategy:
// 1. Keep the vendor client behind this adapter.
// 2. Migrate one screen at a time from completion handlers to stream consumption.
// 3. Inject the protocol into the ViewModel so previews and tests use a fake.
//
// Production notes: bound token buffers before rendering, persist only explicit
// user-approved prompts, and treat cancellation as normal control flow rather
// than an error worth surfacing.

import Foundation

protocol GenerationClient: Sendable {
    func stream(prompt: String) -> AsyncThrowingStream<String, Error>
}

final class VendorModelAdapter: GenerationClient, @unchecked Sendable {
    func stream(prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                // Replace this loop with the SDK callback that yields each token.
                for token in ["A focused", " answer", " streams", " naturally."] {
                    try Task.checkCancellation()
                    try await Task.sleep(for: .milliseconds(80))
                    continuation.yield(token)
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                // This is where I cancel the vendor request to stop token spend.
                task.cancel()
            }
        }
    }
}

@MainActor
final class AssistantViewModel {
    private let client: any GenerationClient
    private(set) var answer = ""

    init(client: any GenerationClient) {
        self.client = client
    }

    func ask(_ prompt: String) async {
        answer = ""
        do {
            for try await token in client.stream(prompt: prompt) {
                answer += token
            }
        } catch is CancellationError {
            // I keep partial output; navigating away is not an app failure.
        } catch {
            answer = "Unable to generate a response."
        }
    }
}
