# Treat AI as an Infrastructure Dependency, Not a View-Model Feature

I used to put prompt construction, retries, and provider calls directly in a view model. It made the demo fast, but it also made cancellation, observability, testing, and a future provider swap all UI concerns.

## Legacy approach

```swift
@MainActor
final class SummaryViewModel {
    var summary = ""

    func summarize(_ article: String) async {
        summary = try! await provider.complete("Summarize: \(article)")
    }
}
```

This couples product copy to a provider prompt, converts ordinary network failure into a crash, and leaves no place to enforce privacy rules or measure latency.

## Modern approach

I make the feature depend on a small capability and put provider-specific work behind it. The use case owns product intent; the gateway owns transport and telemetry.

```swift
import Foundation

struct SummaryRequest: Sendable {
    let article: String
    let maxWords: Int
}

protocol Summarizing: Sendable {
    func summarize(_ request: SummaryRequest) async throws -> String
}

enum SummaryError: Error, LocalizedError {
    case emptyArticle
    case unavailable

    var errorDescription: String? {
        switch self {
        case .emptyArticle: "There is no article to summarize."
        case .unavailable: "Summaries are temporarily unavailable."
        }
    }
}

struct ArticleSummaryUseCase: Sendable {
    private let summarizer: any Summarizing

    init(summarizer: any Summarizing) {
        self.summarizer = summarizer
    }

    func callAsFunction(article: String) async throws -> String {
        let cleaned = article.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw SummaryError.emptyArticle }

        // Product policy belongs here: the UI should not know prompt or size limits.
        return try await summarizer.summarize(
            SummaryRequest(article: cleaned, maxWords: 120)
        )
    }
}

actor SummaryGateway: Summarizing {
    func summarize(_ request: SummaryRequest) async throws -> String {
        // Replace this seam with an API client or on-device model adapter.
        // Keeping it here makes redaction, retries, and tracing consistent.
        guard request.article.count < 50_000 else { throw SummaryError.unavailable }
        return String(request.article.prefix(request.maxWords * 6))
    }
}

@MainActor
final class ArticleViewModel {
    private let summarize: ArticleSummaryUseCase
    private(set) var summary = ""
    private(set) var errorMessage: String?

    init(summarize: ArticleSummaryUseCase) {
        self.summarize = summarize
    }

    func summarize(article: String) async {
        errorMessage = nil
        do {
            summary = try await summarize(article: article)
        } catch is CancellationError {
            // A disappearing screen is not a user-facing failure.
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

## Migration strategy

1. Wrap the existing SDK in `Summarizing`; do not rewrite every screen.
2. Move one stable product workflow into a use case with explicit input limits and failure states.
3. Add a deterministic fake for tests, then record latency, failure class, model/version, and token cost at the gateway.
4. Only after those seams exist, evaluate a hosted provider versus an on-device model for each workflow.

## Production notes

- I keep credentials, raw prompts, and user content out of UI logs; redaction happens before the gateway emits telemetry.
- I propagate cancellation rather than retrying it. Retries are for transient transport failures and must have a bounded budget.
- I version prompts like an API contract and test structured output decoding against real saved fixtures.
- I use a server-side policy boundary for sensitive data. Client-only prompt rules are not a security boundary.
