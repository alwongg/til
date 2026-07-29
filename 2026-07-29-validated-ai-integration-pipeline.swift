// AI Integration in iOS: validate model output at the boundary
//
// Legacy approach
// I used to let a view model accept a String from an AI SDK and decide what it
// meant. That made every caller responsible for parsing, fallback, cancellation,
// and UI-safe state changes.
//
// Modern approach
// I keep the AI client behind an actor, decode its response into a small DTO,
// validate it at the boundary, then return a domain value. The view model sees a
// normal async API rather than provider-specific response shapes.
//
// Migration strategy
// 1. Introduce the protocol beside the existing SDK call.
// 2. Route one feature through the validating adapter.
// 3. Move prompt and provider details behind the protocol once metrics confirm it.
//
// Production notes
// Schema validation is not optional: an LLM can return syntactically valid JSON
// that is semantically unsafe for my feature. I also cap output lengths before
// displaying them and preserve typed failures for observability.

import Foundation

struct AIRecommendation: Decodable, Sendable, Equatable {
    let title: String
    let summary: String

    func validated() throws -> AIRecommendation {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              title.count <= 80 else {
            throw AIError.invalidTitle
        }
        guard !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              summary.count <= 500 else {
            throw AIError.invalidSummary
        }
        return self
    }
}

enum AIError: Error, LocalizedError {
    case malformedResponse
    case invalidTitle
    case invalidSummary

    var errorDescription: String? {
        switch self {
        case .malformedResponse: "The AI response was not the expected JSON."
        case .invalidTitle: "The recommendation title was invalid."
        case .invalidSummary: "The recommendation summary was invalid."
        }
    }
}

protocol AITransport: Sendable {
    func complete(prompt: String) async throws -> Data
}

actor RecommendationService {
    private let transport: any AITransport
    private let decoder = JSONDecoder()

    init(transport: any AITransport) {
        self.transport = transport
    }

    func recommendation(for notes: String) async throws -> AIRecommendation {
        try Task.checkCancellation()
        let prompt = "Return JSON with title and summary for: \(notes)"
        let data = try await transport.complete(prompt: prompt)
        try Task.checkCancellation()

        guard let recommendation = try? decoder.decode(AIRecommendation.self, from: data) else {
            throw AIError.malformedResponse
        }
        return try recommendation.validated()
    }
}

@MainActor
final class RecommendationViewModel {
    private let service: RecommendationService
    private(set) var recommendation: AIRecommendation?
    private(set) var errorMessage: String?

    init(service: RecommendationService) {
        self.service = service
    }

    func refresh(notes: String) async {
        do {
            recommendation = try await service.recommendation(for: notes)
            errorMessage = nil
        } catch is CancellationError {
            // I do not turn a user-initiated cancellation into an error banner.
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
