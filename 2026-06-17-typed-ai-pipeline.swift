import Foundation
import Combine

/*:
 # From stringly AI calls to typed response pipelines

 I used to bolt AI features onto iOS screens by sending a raw prompt, waiting for text,
 and parsing whatever came back inside the view model. It worked for demos, but the failure
 modes were brutal in production: prompt drift, partial JSON, unclear retries, and no real
 boundary between transport, validation, and UI state.

 ## Legacy approach
 - View models built prompts directly.
 - Responses came back as untyped strings.
 - Parsing lived beside presentation logic.
 - Retry policy was ad hoc, usually just "try again".

 ## Modern approach
 I want one pipeline:
 1. a feature asks for a typed use case result,
 2. a gateway handles prompt construction and transport,
 3. decoding and validation happen before UI sees the payload,
 4. recoverable errors are classified for retry or fallback.

 The biggest shift is treating AI like any other unreliable backend: typed inputs, typed outputs,
 explicit error surfaces, and deterministic post-processing.

 ## Example
 */

protocol LLMClient {
    func complete(prompt: String) async throws -> String
}

enum AIError: Error, LocalizedError {
    case emptyResponse
    case invalidPayload
    case unsupportedIntent

    var errorDescription: String? {
        switch self {
        case .emptyResponse:
            return "The model returned an empty response."
        case .invalidPayload:
            return "The model payload could not be decoded safely."
        case .unsupportedIntent:
            return "The requested AI intent is not supported."
        }
    }
}

struct SummarizationRequest: Sendable {
    let title: String
    let notes: String
}

struct SummarizationResult: Codable, Sendable, Equatable {
    let headline: String
    let bullets: [String]
    let confidence: Double
}

struct PromptBuilder {
    func makePrompt(for request: SummarizationRequest) -> String {
        """
        You are generating a compact study summary for an iOS engineer.
        Return valid JSON with keys: headline, bullets, confidence.

        Title: \(request.title)
        Notes: \(request.notes)
        """
    }
}

struct JSONResponseDecoder {
    let decoder: JSONDecoder = JSONDecoder()

    func decodeSummary(from raw: String) throws -> SummarizationResult {
        let data = Data(raw.utf8)
        guard !data.isEmpty else { throw AIError.emptyResponse }

        do {
            return try decoder.decode(SummarizationResult.self, from: data)
        } catch {
            throw AIError.invalidPayload
        }
    }
}

actor StudySummaryGateway {
    private let client: LLMClient
    private let promptBuilder = PromptBuilder()
    private let responseDecoder = JSONResponseDecoder()

    init(client: LLMClient) {
        self.client = client
    }

    func summarize(_ request: SummarizationRequest) async throws -> SummarizationResult {
        let prompt = promptBuilder.makePrompt(for: request)
        let raw = try await client.complete(prompt: prompt)
        return try responseDecoder.decodeSummary(from: raw)
    }
}

@MainActor
final class LessonViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case loaded(SummarizationResult)
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    private let gateway: StudySummaryGateway

    init(gateway: StudySummaryGateway) {
        self.gateway = gateway
    }

    func generateSummary(title: String, notes: String) {
        state = .loading

        Task {
            do {
                let request = SummarizationRequest(title: title, notes: notes)
                let result = try await gateway.summarize(request)
                state = .loaded(result)
            } catch {
                // The UI gets a stable failure surface instead of model-specific chaos.
                state = .failed(error.localizedDescription)
            }
        }
    }
}

/*:
 ## Migration strategy
 - Start by extracting prompt building out of the view model.
 - Add typed request/response models before changing the UI.
 - Centralize decode + validation so malformed output dies at the boundary.
 - Classify errors into retryable, fallback, and user-visible buckets.

 ## Production notes
 - Keep prompts versioned when the output contract matters.
 - Log model latency and invalid-payload rate per feature, not just global success.
 - Add cheap deterministic guards after decoding; JSON validity is not product validity.
 - Treat the AI layer like a repository boundary so I can swap vendors without rewriting screens.

 My rule now: AI code only feels real when the Swift side is more disciplined than the prompt side.
 */
