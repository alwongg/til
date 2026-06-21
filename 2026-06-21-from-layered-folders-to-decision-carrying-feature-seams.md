# From layered folders to decision-carrying feature seams

I used to judge iOS architecture by folder depth. If I had `Models`, `Views`, `ViewModels`, `Services`, and `Utilities`, it felt organized. The problem was that the structure looked clean while the decisions were still smeared across the app. Networking knew presentation timing, view models knew retry policy, and feature flags leaked into random helpers.

## Legacy approach
- I grouped code by technical type instead of by product decision.
- Reuse happened too early, so shared abstractions were vague and hard to delete.
- Async work started wherever it was convenient, which made cancellation and ownership fuzzy.
- When a feature changed, I had to touch five directories because the seam lived in my head instead of in the codebase.

## Modern approach
I design feature seams around decisions that change together: data source, business rule, async boundary, and UI state.

```swift
protocol InboxRepository {
    func fetchThreads() async throws -> [MessageThread]
}

struct LoadInbox {
    let repository: InboxRepository

    func execute() async throws -> [InboxRowModel] {
        try await repository.fetchThreads().map(InboxRowModel.init)
    }
}

@MainActor
final class InboxViewModel: ObservableObject {
    @Published private(set) var rows: [InboxRowModel] = []
    @Published private(set) var state: ViewState = .idle

    private let loadInbox: LoadInbox

    init(loadInbox: LoadInbox) {
        self.loadInbox = loadInbox
    }

    func refresh() async {
        state = .loading
        do {
            rows = try await loadInbox.execute()
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
```

The point for me is not “use a use case because Clean Architecture said so.” The point is that the feature has one place where loading policy lives, one place where UI state changes, and one place where infrastructure gets swapped.

## Migration strategy
1. Pick one unstable feature instead of reorganizing the whole app.
2. Name the business action first (`LoadInbox`, `SubmitOrder`, `RefreshPortfolio`) before naming folders.
3. Pull network/database details behind a repository only when the feature truly needs that swap point.
4. Keep async entry points explicit so I can reason about cancellation, task lifetime, and `@MainActor` hops.
5. Move cross-feature code into shared modules only after two real features prove the same shape.

## Production notes
- If a view model contains formatting, retries, analytics, and API orchestration, I treat that as multiple responsibilities hiding behind one class.
- I like repositories when they isolate infrastructure, but I avoid turning them into generic CRUD wrappers with no product language.
- Good architecture reduces blast radius. When product changes the loading rule, I want one feature seam to absorb it.
- The best test of a seam is replacement pressure: can I swap the backend, fake the data, or change the screen flow without rewriting the whole stack?

My architecture heuristic now is simple: I stop organizing around what the code is and organize around what decision it protects.