// AI Integration in iOS: migrate from a screen-owned request to a typed feature boundary
//
// Legacy approach
// I used to let a view model build prompts, call a vendor SDK, and parse untyped text.
// That made cancellation, retries, provider swaps, and malformed responses UI concerns.
//
// Modern approach
// I keep the model provider behind an actor-backed client and return a small domain type.
// The view model asks for an outcome, not a prompt or a JSON string.

import Foundation

struct MeetingSummary: Sendable, Equatable {
    let title: String
    let actionItems: [String]
}

protocol MeetingSummarizing: Sendable {
    func summarize(transcript: String) async throws -> MeetingSummary
}

enum SummaryError: Error, Equatable {
    case emptyTranscript
    case invalidResponse
}

actor AIClient: MeetingSummarizing {
    private let transport: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    init(transport: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse)) {
        self.transport = transport
    }

    func summarize(transcript: String) async throws -> MeetingSummary {
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SummaryError.emptyTranscript
        }

        // The prompt stays at the integration boundary so UI code cannot accidentally fork it.
        var request = URLRequest(url: URL(string: "https://api.example.com/v1/summaries")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["transcript": transcript])

        let (data, response) = try await transport(request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw SummaryError.invalidResponse
        }
        return try JSONDecoder().decode(MeetingSummary.self, from: data)
    }
}

extension MeetingSummary: Codable {}

// Migration strategy
// 1. Introduce MeetingSummarizing beside the existing SDK call.
// 2. Move prompt construction and decoding into AIClient.
// 3. Inject MeetingSummarizing into the view model; tests use a deterministic fake.
// 4. Add streaming or a second provider inside this boundary, without changing the UI.
//
// Production notes
// - Keep API keys server-side or use short-lived tokens; never ship a provider secret in the app.
// - Log request IDs, latency, and schema failures—not transcripts containing customer data.
// - Treat model output as untrusted: validate size, enum values, and user-visible claims.
