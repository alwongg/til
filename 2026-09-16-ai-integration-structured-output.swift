import Foundation

// AI Integration in iOS Apps: move from loose text to a validated domain result.
// I used to let a model response leak straight into view-state. That made every
// prompt change a UI regression. I now keep the model boundary small and explicit.

struct SupportReply: Codable, Sendable, Equatable {
    let summary: String
    let urgency: Urgency
    let suggestedActions: [String]

    enum Urgency: String, Codable, Sendable {
        case low, medium, high
    }
}

enum AIClientError: Error {
    case invalidResponse
}

protocol AITransport: Sendable {
    func complete(prompt: String) async throws -> Data
}

actor SupportReplyClient {
    private let transport: any AITransport
    private let decoder = JSONDecoder()

    init(transport: any AITransport) {
        self.transport = transport
    }

    func classify(ticket: String) async throws -> SupportReply {
        // The prompt is a contract: JSON only, with enum values I can validate.
        let prompt = """
        Classify this support ticket. Return JSON only with summary, urgency
        (low, medium, or high), and suggestedActions (an array of strings).
        Ticket: \(ticket)
        """

        let data = try await transport.complete(prompt: prompt)
        guard let reply = try? decoder.decode(SupportReply.self, from: data) else {
            // A malformed model answer stays at the boundary instead of poisoning UI state.
            throw AIClientError.invalidResponse
        }
        return reply
    }
}

// Migration strategy:
// 1. Keep my legacy text endpoint behind AITransport.
// 2. Add a schema-shaped prompt and decode it here.
// 3. Instrument decode failures before removing the old fallback.
// Production notes: version the response schema, cap input/output sizes, and
// never make a model response the sole authority for destructive actions.
