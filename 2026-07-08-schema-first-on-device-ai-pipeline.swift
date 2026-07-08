import Foundation

/*
AI Integration in iOS Apps — Schema-First On-Device AI Pipeline

I'm treating AI features like any other production dependency: typed boundaries, cancellation, and fallback paths first.

Legacy approach
- Ship prompt strings directly from the view model.
- Accept free-form text and parse with fragile regex.
- Treat every model response as trustworthy.

Modern approach
- Define a typed request and a typed response.
- Keep prompt construction behind a dedicated service.
- Validate model output before it can touch UI state.
- Fall back to deterministic summaries when the model fails.

Migration strategy
1. Wrap the existing model call in a protocol.
2. Introduce a schema-first response type.
3. Move prompt building out of the view model.
4. Add a fallback path so the feature still works offline or on bad output.

Production notes
- Time-box generation with task cancellation.
- Log decode failures separately from transport failures.
- Keep prompts versioned so analytics can explain regressions.
- The UI should render confidence and source counts, not just the summary string.
*/

struct NoteChunk: Sendable {
    let id: UUID
    let text: String
}

struct SummaryRequest: Sendable {
    let title: String
    let chunks: [NoteChunk]
}

struct SummaryResponse: Codable, Sendable {
    let summary: String
    let actionItems: [String]
    let confidence: Double
}

enum AIIntegrationError: Error {
    case transport(Error)
    case invalidResponse
}

protocol SummarizingModel: Sendable {
    func generateJSON(prompt: String) async throws -> Data
}

struct PromptBuilder: Sendable {
    func makePrompt(for request: SummaryRequest) -> String {
        let joinedNotes = request.chunks
            .map { "- \($0.text)" }
            .joined(separator: "\n")

        return """
        You are summarizing product notes.
        Return strict JSON with keys: summary, actionItems, confidence.
        Title: \(request.title)
        Notes:
        \(joinedNotes)
        """
    }
}

actor NoteSummaryService {
    private let model: SummarizingModel
    private let decoder = JSONDecoder()
    private let promptBuilder = PromptBuilder()

    init(model: SummarizingModel) {
        self.model = model
    }

    func summarize(_ request: SummaryRequest) async -> SummaryResponse {
        do {
            let prompt = promptBuilder.makePrompt(for: request)
            let data = try await model.generateJSON(prompt: prompt)
            let decoded = try decoder.decode(SummaryResponse.self, from: data)

            guard (0...1).contains(decoded.confidence), !decoded.summary.isEmpty else {
                throw AIIntegrationError.invalidResponse
            }

            return decoded
        } catch let error as DecodingError {
            return fallbackSummary(for: request, reason: "decode: \(error)")
        } catch {
            return fallbackSummary(for: request, reason: "runtime: \(error)")
        }
    }

    private func fallbackSummary(for request: SummaryRequest, reason: String) -> SummaryResponse {
        let preview = request.chunks
            .prefix(3)
            .map(\.text)
            .joined(separator: " ")

        return SummaryResponse(
            summary: "Fallback summary: \(preview)",
            actionItems: ["Inspect logs for \(reason)", "Retry with a smaller context window"],
            confidence: 0.35
        )
    }
}
