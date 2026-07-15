import Foundation

/*
# AI Integration in iOS Apps — Streaming Through Domain Boundaries

I used to wire AI SDK callbacks straight into the view model and call it integration.
That worked for demos, but production code got fragile fast: prompt formatting leaked into UI code,
cancellation was inconsistent, and swapping vendors meant touching too many layers.

## Legacy approach
- The view model owned prompt construction.
- The SDK callback appended tokens directly into UI state.
- Retry, cancellation, and throttling were all ad-hoc.

## Modern approach
- I hide the model provider behind a small streaming protocol.
- The use case owns prompt shaping and domain intent.
- The view model only coordinates rendering and user-triggered refreshes.
- An actor enforces request spacing so I don't create accidental bursts.

## Migration strategy
1. Keep the old provider, but wrap it in `AIStreamingClient` first.
2. Move prompt building into one use case per product job.
3. Stream plain domain strings back to the UI, not provider-specific types.
4. Add cancellation and backpressure before adding more prompts.

## Production notes
- Streaming should degrade cleanly on cancellation.
- Rate-limiting belongs beside the request boundary, not inside the view.
- The best AI abstraction is boring: narrow inputs, narrow outputs, no SDK types escaping.
*/

struct AIChunk: Sendable {
    let text: String
}

protocol AIStreamingClient: Sendable {
    func stream(prompt: String) -> AsyncThrowingStream<AIChunk, Error>
}

protocol Summarizing: Sendable {
    func summary(for article: String) -> AsyncThrowingStream<String, Error>
}

struct SummarizeArticleUseCase: Summarizing {
    private let client: AIStreamingClient

    init(client: AIStreamingClient) {
        self.client = client
    }

    func summary(for article: String) -> AsyncThrowingStream<String, Error> {
        let prompt = """
        Summarize the following article for an iPhone user in three short bullets.
        Keep the language direct and practical.

        Article:
        \(article)
        """

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await chunk in client.stream(prompt: prompt) {
                        continuation.yield(chunk.text)
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}

actor AIRequestGate {
    private let minimumDelay: TimeInterval
    private var lastRequestAt: Date?

    init(minimumDelay: TimeInterval = 0.4) {
        self.minimumDelay = minimumDelay
    }

    func waitTurn() async throws {
        let now = Date()

        if let lastRequestAt {
            let elapsed = now.timeIntervalSince(lastRequestAt)
            if elapsed < minimumDelay {
                let remaining = minimumDelay - elapsed
                try await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }
        }

        lastRequestAt = Date()
    }
}

final class ArticleSummaryViewModel {
    private let useCase: Summarizing
    private let gate: AIRequestGate

    private(set) var renderedText = ""

    init(useCase: Summarizing, gate: AIRequestGate = AIRequestGate()) {
        self.useCase = useCase
        self.gate = gate
    }

    func refresh(article: String, onToken: @escaping @Sendable (String) -> Void) async {
        renderedText = ""

        do {
            try await gate.waitTurn()

            for try await token in useCase.summary(for: article) {
                renderedText += token
                onToken(renderedText)
            }
        } catch {
            renderedText = "Failed to summarize: \(error.localizedDescription)"
            onToken(renderedText)
        }
    }
}

struct MockAIClient: AIStreamingClient {
    func stream(prompt: String) -> AsyncThrowingStream<AIChunk, Error> {
        let tokens = [
            "• Start with the user problem, not the model.\n",
            "• Stream domain text into the UI instead of SDK events.\n",
            "• Keep cancellation and pacing at the boundary.\n"
        ]

        return AsyncThrowingStream { continuation in
            let task = Task {
                for token in tokens {
                    try? await Task.sleep(nanoseconds: 40_000_000)
                    continuation.yield(AIChunk(text: token))
                }
                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}
