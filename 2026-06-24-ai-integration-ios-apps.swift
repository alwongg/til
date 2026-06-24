import Foundation

// AI Integration in iOS Apps
//
// Legacy approach
// I used to let AI features leak everywhere: prompt strings inside view models,
// ad-hoc JSON parsing, and no clean boundary between product logic and model calls.
// That works for a spike, but it becomes hard to test and hard to swap providers.
//
// Modern approach
// I now isolate AI behind a protocol, move orchestration into an actor, and keep
// the feature asking for a typed domain result instead of raw model text.
//
// Migration strategy
// 1. Wrap the existing provider in AIClient.
// 2. Define a typed response boundary near the feature.
// 3. Move prompt assembly into a dedicated pipeline actor.
// 4. Add logging, fallback behavior, and deterministic tests.
//
// Production notes
// I want prompt versioning, latency measurement, and a redaction step before
// data leaves the device boundary.

struct Article: Sendable {
    let title: String
    let body: String
}

struct Summary: Sendable {
    let headline: String
    let bullets: [String]
}

protocol AIClient: Sendable {
    func complete(system: String, user: String) async throws -> String
}

actor SummaryPipeline {
    private let client: AIClient

    init(client: AIClient) {
        self.client = client
    }

    func summarize(_ article: Article) async throws -> Summary {
        let system = "Return one headline and up to three bullet points."
        let user = "Title: \(article.title)\nBody: \(article.body)"
        let raw = try await client.complete(system: system, user: user)
        return SummaryParser.parse(raw)
    }
}

enum SummaryParser {
    static func parse(_ text: String) -> Summary {
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let headline = lines.first ?? "Summary unavailable"
        let bullets = lines.dropFirst().map { line in
            line.replacingOccurrences(of: "- ", with: "")
        }
        return Summary(headline: headline, bullets: Array(bullets.prefix(3)))
    }
}

struct MockAIClient: AIClient {
    func complete(system: String, user: String) async throws -> String {
        _ = system
        _ = user
        return "On-device summarization boundary\n- Keep provider logic behind a protocol\n- Parse into domain types early\n- Log latency and prompt versions"
    }
}
