import Foundation

// 2026-06-10 — AI Integration in iOS Apps
// Title: On-Device AI Pipelines with Structured Concurrency
//
// I don't want AI features to feel like a bolt-on network request sitting behind
// a button tap. In production, I need cancellation, bounded memory, and a clean
// handoff between feature state, model loading, and result rendering.
//
// This lesson compares the legacy "fire one giant task" approach with a modern
// pipeline that keeps model access isolated behind an actor and gives the screen
// explicit progress updates.

struct DraftSummary: Sendable {
    let headline: String
    let bullets: [String]
}

enum SummarizationError: Error {
    case emptyTranscript
}

protocol LocalModelServing: Sendable {
    func summarize(transcript: String) async throws -> DraftSummary
}

// Legacy approach: view models often own orchestration directly. That works for
// demos, but it hides cancellation and makes model lifecycle hard to reason about.
@MainActor
final class LegacySessionViewModel {
    private let model: LocalModelServing
    private(set) var status = "Idle"
    private(set) var renderedText = ""

    init(model: LocalModelServing) {
        self.model = model
    }

    func summarize(transcript: String) {
        status = "Running"

        Task {
            do {
                let summary = try await model.summarize(transcript: transcript)
                renderedText = ([summary.headline] + summary.bullets.map { "• \($0)" })
                    .joined(separator: "\n")
                status = "Done"
            } catch {
                renderedText = ""
                status = "Failed"
            }
        }
    }
}

// Modern approach: the feature asks a coordinator to drive a staged pipeline.
// The actor owns model warmup and inference so overlapping requests stay safe.
actor ModelRuntime {
    private var isWarmed = false
    private let model: LocalModelServing

    init(model: LocalModelServing) {
        self.model = model
    }

    func warmIfNeeded() async throws {
        guard !isWarmed else { return }
        try await Task.sleep(nanoseconds: 40_000_000)
        isWarmed = true
    }

    func summarize(transcript: String) async throws -> DraftSummary {
        try await warmIfNeeded()
        return try await model.summarize(transcript: transcript)
    }
}

enum SessionPhase: Sendable {
    case preparingInput
    case runningInference
    case renderingResult
    case finished(DraftSummary)
}

struct SummarizeMeetingUseCase: Sendable {
    let runtime: ModelRuntime

    func execute(transcript: String) -> AsyncThrowingStream<SessionPhase, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    continuation.finish(throwing: SummarizationError.emptyTranscript)
                    return
                }

                continuation.yield(.preparingInput)
                let normalized = transcript
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")

                continuation.yield(.runningInference)
                let summary = try await runtime.summarize(transcript: normalized)

                continuation.yield(.renderingResult)
                continuation.yield(.finished(summary))
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

@MainActor
final class MeetingSummaryViewModel {
    private let useCase: SummarizeMeetingUseCase

    private(set) var status = "Idle"
    private(set) var outputLines: [String] = []

    init(useCase: SummarizeMeetingUseCase) {
        self.useCase = useCase
    }

    func summarize(transcript: String) async {
        outputLines.removeAll()

        do {
            for try await phase in useCase.execute(transcript: transcript) {
                switch phase {
                case .preparingInput:
                    status = "Preparing transcript"
                case .runningInference:
                    status = "Running on-device model"
                case .renderingResult:
                    status = "Formatting summary"
                case .finished(let summary):
                    status = "Done"
                    outputLines = [summary.headline] + summary.bullets.map { "• \($0)" }
                }
            }
        } catch {
            status = "Failed"
            outputLines = ["Keep inference boundaries explicit so failures stay local to the feature."]
        }
    }
}

// Migration strategy:
// 1. I keep my existing prompt and post-processing logic, but move model access
//    behind a runtime actor first.
// 2. I replace one-shot completion handlers with AsyncThrowingStream when the UI
//    needs visible phases like warmup, inference, and rendering.
// 3. I let the feature depend on a use case, not directly on Core ML / local LLM
//    wiring, so tests can swap in a deterministic fake.
// 4. I cancel the stream when the screen disappears so expensive inference does
//    not outlive the user interaction that requested it.

// Production notes:
// - Warmup is usually the hidden tax. I measure first-token latency separately
//   from steady-state throughput.
// - Actor isolation gives me one place to gate memory-heavy model state.
// - Streaming phase updates keeps SwiftUI honest: the UI reflects real work
//   instead of pretending everything is a single loading spinner.
// - If I later move from a fake model to Core ML or a local LLM bridge, the
//   feature contract stays stable.

struct FakeOnDeviceModel: LocalModelServing {
    func summarize(transcript: String) async throws -> DraftSummary {
        try await Task.sleep(nanoseconds: 60_000_000)

        let words = transcript
            .split(separator: " ")
            .map(String.init)

        let headline = words.prefix(6).joined(separator: " ") + "..."
        let bulletA = "Capture the task owner before leaving the screen."
        let bulletB = "Persist model warmup separately from feature navigation state."
        let bulletC = "Design the API so cancellation is a normal path, not an exception."

        return DraftSummary(headline: headline, bullets: [bulletA, bulletB, bulletC])
    }
}

@main
struct DemoApp {
    static func main() async {
        let runtime = ModelRuntime(model: FakeOnDeviceModel())
        let useCase = SummarizeMeetingUseCase(runtime: runtime)
        let viewModel = MeetingSummaryViewModel(useCase: useCase)

        await viewModel.summarize(
            transcript: "Ship the summarizer behind a feature flag, capture latency, and review failures before enabling it for every account."
        )

        print(viewModel.status)
        print(viewModel.outputLines.joined(separator: "\n"))
    }
}
