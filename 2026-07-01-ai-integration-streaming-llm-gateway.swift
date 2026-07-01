import Foundation

// # AI Integration in iOS Apps — From Fire-and-Forget Requests to a Streaming LLM Gateway
//
// I used to bolt AI features onto an app with a single async function:
// send one prompt, wait for one response, then dump the text into a view model.
// That worked for demos, but production apps need better seams for streaming,
// cancellation, prompt versioning, and testability.
//
// ## Legacy approach
// - View models called URLSession directly.
// - Prompts were assembled inline in SwiftUI actions.
// - Responses arrived as one giant blob, so the UI felt frozen.
// - Cancellation was an afterthought, which meant wasted tokens and flaky UX.
//
// ## Modern approach
// I prefer an actor-isolated gateway that accepts a typed request and returns an
// AsyncThrowingStream of tokens. The view model doesn't know transport details.
// It only knows how to consume partial output and react to task cancellation.
//
// ## Migration strategy
// 1. Move prompt construction into a dedicated request type.
// 2. Hide the provider behind a transport protocol.
// 3. Stream partial output first, even if the backend still returns one chunk.
// 4. Add prompt version tags so analytics can compare prompt changes safely.
//
// ## Production notes
// - Keep the system prompt versioned, not hard-coded in views.
// - Debounce user-triggered generations so retries don't stack.
// - Surface cancellation distinctly from provider failures.
// - Log token latency per chunk; the first token is the UX that matters most.

struct PromptTemplate: Sendable {
    let version: String
    let system: String

    func render(userText: String, context: [String]) -> String {
        let joinedContext = context.joined(separator: "\n- ")
        return """
        [system v\(version)]
        \(system)

        Relevant app context:
        - \(joinedContext)

        User input:
        \(userText)
        """
    }
}

struct GenerationRequest: Sendable {
    let feature: String
    let userText: String
    let context: [String]
    let template: PromptTemplate

    var prompt: String {
        template.render(userText: userText, context: context)
    }
}

enum AIProviderError: Error, Sendable {
    case cancelled
    case emptyResponse
}

protocol AITransport: Sendable {
    func stream(prompt: String) -> AsyncThrowingStream<String, Error>
}

actor LLMGateway {
    private let transport: AITransport

    init(transport: AITransport) {
        self.transport = transport
    }

    func generate(request: GenerationRequest) -> AsyncThrowingStream<String, Error> {
        transport.stream(prompt: request.prompt)
    }
}

@MainActor
final class AIComposerViewModel: ObservableObject {
    @Published private(set) var draft = ""
    @Published private(set) var status = "Idle"

    private let gateway: LLMGateway
    private var generationTask: Task<Void, Never>?

    init(gateway: LLMGateway) {
        self.gateway = gateway
    }

    func generateReleaseNotes(from changeLog: String) {
        generationTask?.cancel()

        let request = GenerationRequest(
            feature: "release-notes",
            userText: changeLog,
            context: [
                "Audience: App Store users",
                "Tone: clear, concrete, no hype",
                "Max length: 3 bullets"
            ],
            template: PromptTemplate(
                version: "2026-07-release-notes-v2",
                system: "Rewrite technical changes into concise customer-facing release notes."
            )
        )

        generationTask = Task {
            draft = ""
            status = "Streaming"

            do {
                let stream = await gateway.generate(request: request)
                for try await token in stream {
                    try Task.checkCancellation()
                    draft += token
                }

                if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    throw AIProviderError.emptyResponse
                }

                status = "Done"
            } catch is CancellationError {
                status = "Cancelled"
            } catch AIProviderError.emptyResponse {
                status = "Empty response"
            } catch {
                status = "Failed: \(error.localizedDescription)"
            }
        }
    }
}

struct MockStreamingTransport: AITransport {
    func stream(prompt: String) -> AsyncThrowingStream<String, Error> {
        let preview = prompt.prefix(40)

        return AsyncThrowingStream { continuation in
            let chunks = [
                "• Faster launch performance\n",
                "• Improved offline reliability\n",
                "• Clearer account recovery flow\n",
                "\n[prompt preview: \(preview)]"
            ]

            Task {
                for chunk in chunks {
                    try Task.checkCancellation()
                    continuation.yield(chunk)
                }
                continuation.finish()
            }
        }
    }
}
