# Boundary-First Architecture: A Sunday Reflection

I use Sunday lessons to pressure-test the architectural choices I made during the week. The most useful question is not “which pattern did I use?” It is: **where can a change enter this feature, and how far can it spread?**

## The legacy shape: a view model that knows everything

Early in an iOS feature, it is tempting to let a view model call `URLSession`, decode models, format strings, decide retry behaviour, and update UI state. It feels efficient because the feature is small.

```swift
@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var name = ""

    func load() async {
        let url = URL(string: "https://api.example.com/profile")!
        let (data, _) = try! await URLSession.shared.data(from: url)
        let profile = try! JSONDecoder().decode(Profile.self, from: data)
        name = "Hello, \(profile.firstName)"
    }
}
```

The cost appears later. A backend change touches presentation code. A retry policy is duplicated. Tests need the network. Product rules become hidden in UI methods.

## The modern shape: boundaries that name responsibility

I prefer a narrow flow:

```text
View -> ViewModel -> Use Case -> Repository -> Remote / Local data source
```

Each boundary has a question it answers:

- **View:** What should the user see and do?
- **View model:** What UI state represents the work?
- **Use case:** What product decision are we making?
- **Repository:** Where does this data come from, and what is the stable app-facing contract?
- **Data source:** How is this particular system contacted or stored?

```swift
protocol ProfileRepository: Sendable {
    func profile() async throws -> Profile
}

struct LoadProfile {
    let repository: any ProfileRepository

    func callAsFunction() async throws -> Profile {
        try await repository.profile()
    }
}

@MainActor
final class ProfileViewModel: ObservableObject {
    enum State { case idle, loading, loaded(String), failed(String) }
    @Published private(set) var state: State = .idle

    private let loadProfile: LoadProfile

    init(loadProfile: LoadProfile) {
        self.loadProfile = loadProfile
    }

    func load() async {
        state = .loading
        do {
            let profile = try await loadProfile()
            state = .loaded("Hello, \(profile.firstName)")
        } catch {
            state = .failed("Couldn’t load your profile.")
        }
    }
}
```

The point is not ceremony. `LoadProfile` is now a testable place for product rules: cached data, account eligibility, analytics, or a fallback. The view model remains a translator between domain outcomes and UI state.

## Migration strategy: carve a seam before moving code

I do not rewrite a working feature into five layers at once. I migrate in this order:

1. Extract the network call behind a repository protocol while keeping the existing view model API.
2. Add a use case only when there is a real product decision, orchestration step, or reuse case.
3. Move formatting that is truly presentation-specific back toward the view model or view.
4. Write one focused test at each new seam before expanding it.

This keeps the risk proportional. If the abstraction does not remove a dependency, clarify a rule, or make a test easier, I delete it.

## Production notes

- Inject protocols at the composition root; do not construct production repositories inside a view model.
- Make failure states explicit. A generic `Error` belongs at the boundary, but the UI needs a deliberate recovery state.
- Treat caching and retry as policies owned by the use case or repository, not accidental details of a screen.
- Keep feature boundaries vertical. A `Profile` feature can own its model, repository contract, use case, and view model without creating a global “services” folder.
- Measure architecture by change isolation. When an API, experiment, or UI flow changes, I want to know exactly which layer should move.

My weekly checkpoint: I choose one feature and trace a likely change through it. If the change crosses more layers than its responsibility requires—or leaks into unrelated features—I have found the next seam worth improving.
