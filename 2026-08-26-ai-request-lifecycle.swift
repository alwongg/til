// AI Integration in iOS: make request lifetime explicit
//
// My old approach let a view fire an AI request and hope the response still
// mattered when it returned. That produces stale UI, duplicate work, and
// cancellation that looks successful but does not actually stop delivery.
//
// My modern baseline is to give each visible request an ID. Starting a new
// request cancels the previous task; only the current ID can publish state.
// The service is injected so the UI layer owns presentation, not transport.

import Foundation

struct AIResponse: Sendable, Equatable {
    let text: String
}

protocol AIResponding: Sendable {
    func respond(to prompt: String) async throws -> AIResponse
}

enum AIRequestState: Sendable, Equatable {
    case idle
    case loading
    case loaded(AIResponse)
    case failed(String)
}

@MainActor
final class AIRequestViewModel {
    private let service: any AIResponding
    private var activeRequestID: UUID?
    private var activeTask: Task<Void, Never>?

    private(set) var state: AIRequestState = .idle

    init(service: any AIResponding) {
        self.service = service
    }

    func submit(_ prompt: String) {
        activeTask?.cancel()

        let requestID = UUID()
        activeRequestID = requestID
        state = .loading

        activeTask = Task { [weak self, service] in
            do {
                let response = try await service.respond(to: prompt)
                guard !Task.isCancelled, self?.activeRequestID == requestID else { return }
                self?.state = .loaded(response)
            } catch is CancellationError {
                // Cancellation is expected when the user changes the prompt.
            } catch {
                guard !Task.isCancelled, self?.activeRequestID == requestID else { return }
                self?.state = .failed(error.localizedDescription)
            }
        }
    }

    func cancel() {
        activeTask?.cancel()
        activeTask = nil
        activeRequestID = nil
        state = .idle
    }
}

// A deterministic service keeps previews and tests independent of a network.
struct PreviewAIService: AIResponding {
    func respond(to prompt: String) async throws -> AIResponse {
        try await Task.sleep(for: .milliseconds(50))
        try Task.checkCancellation()
        return AIResponse(text: "Draft for: \(prompt)")
    }
}

// Migration strategy:
// 1. Wrap the existing callback client behind AIResponding.
// 2. Move request ownership into one @MainActor view model per screen.
// 3. Add streaming later as a separate state transition, not as string
//    concatenation inside the view.
//
// Production notes:
// - Persist neither raw prompts nor responses by default; they may contain PII.
// - Record request ID, latency, model version, and outcome in telemetry.
// - Apply server-side rate limits and validate tool inputs before execution.
