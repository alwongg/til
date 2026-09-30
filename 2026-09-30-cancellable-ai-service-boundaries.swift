# Streaming AI Features: Move From View-Owned Requests to a Cancellable Domain Service

I treat an AI response as a long-running, fallible stream—not a button action that happens to return text. That distinction keeps SwiftUI views responsive and makes cancellation, retries, and observability testable.

## Legacy approach

```swift
// A view starts URLSession work directly, owns parsing, and mutates UI state.
// Cancellation and request policy become difficult to test or reuse.
Task {
    let (data, _) = try await URLSession.shared.data(from: url)
    answer = String(decoding: data, as: UTF8.self)
}
```

This is fine for a prototype, but production problems leak upward: duplicate taps make duplicate requests, navigating away may leave work running, and every screen invents its own error handling.

## Modern approach

```swift
import Foundation

struct AIRequest: Encodable, Sendable {
    let prompt: String
}

enum AIServiceError: Error {
    case invalidResponse
}

protocol AIResponding: Sendable {
    func answer(to prompt: String) async throws -> String
}

actor AIService: AIResponding {
    private let session: URLSession
    private let endpoint: URL

    init(endpoint: URL, session: URLSession = .shared) {
        self.endpoint = endpoint
        self.session = session
    }

    func answer(to prompt: String) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(AIRequest(prompt: prompt))

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              200..<300 ~= http.statusCode else {
            throw AIServiceError.invalidResponse
        }
        return String(decoding: data, as: UTF8.self)
    }
}

@MainActor
final class AssistantViewModel {
    private let service: any AIResponding
    private var requestTask: Task<Void, Never>?
    private(set) var answer = ""

    init(service: any AIResponding) { self.service = service }

    func submit(_ prompt: String) {
        requestTask?.cancel() // A newer intent always supersedes the old one.
        requestTask = Task {
            do {
                answer = try await service.answer(to: prompt)
            } catch is CancellationError {
                // Cancellation is expected when the user edits or leaves.
            } catch {
                answer = "Please try again."
            }
        }
    }

    deinit { requestTask?.cancel() }
}
```

The view model owns presentation state and cancellation policy; the actor owns request construction and transport. A test can inject a fake `AIResponding` implementation without touching the network.

## Migration strategy

1. Extract the existing request into an `AIResponding` protocol before changing UI code.
2. Inject a real service at the composition root and a controllable fake in tests.
3. Add cancellation first; then introduce token streaming as `AsyncThrowingStream<String, Error>` behind the same boundary.
4. Keep server credentials off-device—my iOS app calls a backend that enforces auth, rate limits, and model policy.

## Production notes

- I record latency, cancellation rate, status code, and a privacy-safe request category—not raw prompts or completions.
- I set explicit timeouts and distinguish retryable transport failures from validation failures.
- Streaming needs bounded UI updates (for example, coalescing tokens) so a fast model does not cause excessive SwiftUI invalidation.
- A response is untrusted input: I validate structured output at the domain boundary before it can affect app state.
