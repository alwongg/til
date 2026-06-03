import Foundation

/*:
 # From Prompt-in-the-ViewModel to a Tool-Aware AI Feature Boundary

 I still see AI features get added to iOS apps the same way networking spikes used to: one fast experiment lands in a view model, then the prompt, request building, parsing, retry logic, and product rules all stay there longer than they should.

 That approach is fine for proving value, but it becomes fragile once the feature needs analytics, fallback behavior, token budgeting, or a second model provider.

 When I want the AI integration to survive product growth, I move it behind a feature boundary with three explicit jobs:
 - a session that knows how to talk to the model
 - a tool layer that exposes app capabilities in typed form
 - a use case that decides what the feature is actually allowed to do

 ## Legacy approach

 This is the kind of shape I try to retire early:

 ```swift
 final class LegacyTripIdeasViewModel: ObservableObject {
     @Published var summary = ""

     func generateTripIdeas(for notes: String) {
         let prompt = "Read these notes and suggest a weekend itinerary in Toronto: \(notes)"

         AIClient.shared.complete(prompt: prompt) { result in
             switch result {
             case .success(let text):
                 DispatchQueue.main.async {
                     self.summary = text
                 }
             case .failure:
                 DispatchQueue.main.async {
                     self.summary = "Could not generate ideas."
                 }
             }
         }
     }
 }
 ```

 It looks tiny, but the coupling starts immediately:
 - prompt wording is glued to UI state
 - model access is hard-coded
 - app data cannot be exposed safely as tools
 - output parsing is unstructured
 - testing product rules means testing the view model

 ## Modern approach

 I prefer a typed boundary where the app owns the workflow and the model fills in one narrow part of it.

 ```swift
 struct TripRequest: Sendable {
     let city: String
     let tripNotes: String
 }

 struct WeatherSnapshot: Sendable {
     let summary: String
     let temperatureCelsius: Int
 }

 struct ItineraryDraft: Sendable {
     let title: String
     let bullets: [String]
 }

 protocol WeatherTool: Sendable {
     func fetchWeather(for city: String) async throws -> WeatherSnapshot
 }

 struct StubWeatherTool: WeatherTool {
     func fetchWeather(for city: String) async throws -> WeatherSnapshot {
         try await Task.sleep(for: .milliseconds(25))
         return WeatherSnapshot(summary: "Sunny", temperatureCelsius: 22)
     }
 }

 struct AIMessage: Sendable {
     let role: String
     let content: String
 }

 protocol AISession: Sendable {
     func complete(messages: [AIMessage]) async throws -> String
 }

 struct StubAISession: AISession {
     func complete(messages: [AIMessage]) async throws -> String {
         let transcript = messages.map(\ .content).joined(separator: "
")
         guard transcript.contains("Sunny") else {
             throw NSError(domain: "Demo", code: 1)
         }

         return "Waterfront Reset
- Start with coffee near Union
- Walk the lake in the afternoon sun
- Keep dinner flexible for energy levels"
     }
 }

 struct DraftTripIdeasUseCase: Sendable {
     let weatherTool: any WeatherTool
     let aiSession: any AISession

     func execute(_ request: TripRequest) async throws -> ItineraryDraft {
         let weather = try await weatherTool.fetchWeather(for: request.city)

         let messages = [
             AIMessage(
                 role: "system",
                 content: "You write grounded, realistic iOS travel assistant output. Keep it concise."
             ),
             AIMessage(
                 role: "user",
                 content: """
                 City: \(request.city)
                 Weather: \(weather.summary), \(weather.temperatureCelsius)C
                 Notes: \(request.tripNotes)

                 Return a short title on the first line, then 3 bullet lines.
                 """
             )
         ]

         let raw = try await aiSession.complete(messages: messages)
         return try parse(raw)
     }

     private func parse(_ raw: String) throws -> ItineraryDraft {
         let lines = raw
             .split(separator: "
")
             .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
             .filter { !$0.isEmpty }

         guard let title = lines.first else {
             throw NSError(domain: "Parser", code: 1)
         }

         let bullets = lines
             .dropFirst()
             .map { $0.replacingOccurrences(of: "- ", with: "") }

         guard bullets.count >= 2 else {
             throw NSError(domain: "Parser", code: 2)
         }

         return ItineraryDraft(title: title, bullets: bullets)
     }
 }

 @MainActor
 final class TripIdeasViewModel {
     private let draftTripIdeas: DraftTripIdeasUseCase

     private(set) var title = ""
     private(set) var bullets: [String] = []
     private(set) var errorText: String?

     init(draftTripIdeas: DraftTripIdeasUseCase) {
         self.draftTripIdeas = draftTripIdeas
     }

     func load(notes: String) async {
         do {
             let draft = try await draftTripIdeas.execute(
                 TripRequest(city: "Toronto", tripNotes: notes)
             )
             title = draft.title
             bullets = draft.bullets
             errorText = nil
         } catch {
             title = ""
             bullets = []
             errorText = "Could not generate ideas."
         }
     }
 }

 @main
 enum Demo {
     static func main() async {
         let useCase = DraftTripIdeasUseCase(
             weatherTool: StubWeatherTool(),
             aiSession: StubAISession()
         )
         let viewModel = TripIdeasViewModel(draftTripIdeas: useCase)

         await viewModel.load(notes: "Dog-friendly, low-friction, not too packed")
         print(viewModel.title)
         print(viewModel.bullets)
         print(viewModel.errorText ?? "ok")
     }
 }
 ```

 What I like about this split:
 - the tool boundary is typed, so app capabilities are not leaked through ad hoc prompt text
 - the AI session is replaceable, which matters once pricing, latency, or quality changes
 - parsing happens at the use-case edge instead of bleeding into presentation code
 - the view model goes back to owning UI state instead of becoming an orchestration dump

 ## Migration strategy

 I usually move an existing AI feature in four steps:

 1. Wrap the current model call behind a small `AISession` protocol without changing the UI behavior.
 2. Pull any app lookups like weather, calendar, or account data into explicit tools first.
 3. Add structured parsing at the use-case boundary so the UI never depends on free-form prose.
 4. Only after those seams exist, swap prompts, providers, or model sizes more aggressively.

 That order keeps the product stable while making the AI path easier to test and reason about.

 ## Production notes

 - I treat prompts as behavior, but not as the architecture. The architecture is the boundary around them.
 - Tool outputs should be compact and typed; giant context blobs usually hide product indecision.
 - If a model answer can trigger a user-visible action, I want a policy layer before the UI trusts it.
 - Logging raw model output is useful during rollout, but I still convert it to typed domain data as early as possible.
 - The fastest way to make an AI feature brittle is to let presentation, prompting, and business rules evolve in the same file.

 The transformation I want is not “use more AI.” It is making the AI feature behave like the rest of the codebase: explicit seams, testable rules, and clear ownership.
 */
