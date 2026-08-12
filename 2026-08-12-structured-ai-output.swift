# AI Integration in iOS Apps: Turn Model Text into a Typed Boundary

I do not let a generative model write directly into my UI state. The model is probabilistic; my app contract should not be. I treat its response as untrusted transport data, decode it at one boundary, and expose only domain types to the rest of the feature.

## Legacy approach

The tempting implementation is to await a string, split it or hand it to a view, then hope every prompt revision still produces the shape the UI expects. That makes parsing rules leak through the feature and turns a malformed response into a rendering bug.

## Modern approach

I request JSON matching a small `Decodable` schema. The actor below owns the transport dependency and validates the response before it reaches a view model. The view model can now render `Recommendation`, not model text.

```swift
import Foundation

struct Recommendation: Codable, Sendable {
    let title: String
    let rationale: String
    let confidence: Double
}

protocol AITransport: Sendable {
    func complete(prompt: String) async throws -> Data
}

enum AIOutputError: Error { case invalidConfidence }

actor RecommendationClient {
    private let transport: any AITransport

    init(transport: any AITransport) { self.transport = transport }

    func recommend(for request: String) async throws -> Recommendation {
        let data = try await transport.complete(prompt: request)
        let result = try JSONDecoder().decode(Recommendation.self, from: data)
        guard (0...1).contains(result.confidence) else {
            throw AIOutputError.invalidConfidence
        }
        return result
    }
}
```

## Migration strategy

1. Define the smallest output schema the screen actually needs.
2. Put the schema in the prompt and require JSON only.
3. Decode and validate in a client or repository, never in the view.
4. Map failures to a retryable product state; log the raw response securely for diagnosis.

## Production notes

I keep the model behind `AITransport` so previews and tests can inject deterministic fixtures. I version prompts and schemas together: adding a required property is an API change, even when the API happens to be a prompt. For sensitive flows, I add server-side policy checks rather than trusting a confidence score supplied by the model.
