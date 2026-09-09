// AI Integration in iOS: Stream Through a Gateway, Not My View Model
//
// I keep vendor SDKs out of my feature layer. The view model depends on a tiny
// streaming protocol, so I can swap a hosted model, an on-device model, or a fake
// without rewriting UI state management.

import Foundation

struct Prompt: Sendable {
    let text: String
}

protocol TextGenerationClient: Sendable {
    func stream(_ prompt: Prompt) -> AsyncThrowingStream<String, Error>
}

@MainActor
final class AssistantViewModel {
    private let client: any TextGenerationClient
    private(set) var answer = ""
    private(set) var isGenerating = false

    init(client: any TextGenerationClient) {
        self.client = client
    }

    func generate(for prompt: String) async {
        guard !isGenerating else { return }
        answer = ""
        isGenerating = true
        defer { isGenerating = false } // State resets on cancellation and errors.

        do {
            for try await token in client.stream(Prompt(text: prompt)) {
                answer += token
            }
        } catch is CancellationError {
            // Cancellation is expected when the user changes their mind.
        } catch {
            answer = "Unable to generate a response."
        }
    }
}

// A deterministic fake makes streaming UI tests fast and network-free.
struct PreviewTextClient: TextGenerationClient {
    func stream(_ prompt: Prompt) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                for token in ["Keep ", "model ", "providers ", "behind ", "a gateway."] {
                    try? await Task.sleep(for: .milliseconds(50))
                    guard !Task.isCancelled else {
                        continuation.finish(throwing: CancellationError())
                        return
                    }
                    continuation.yield(token)
                }
                continuation.finish()
            }
        }
    }
}
