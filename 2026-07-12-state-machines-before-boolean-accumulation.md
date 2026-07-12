# Reflection & Architecture Thinking — State Machines Before Boolean Accumulation

One architecture smell I trust a lot now is boolean accumulation.

If a screen keeps growing flags like `isLoading`, `isRefreshing`, `showError`, `hasLoadedOnce`, and `isEmpty`, I stop assuming I just need one more conditional. Usually that means the feature has state transitions I never modeled clearly.

## Legacy approach

I used to let screens evolve like this:

- add one loading flag for the first network call
- add another flag when pull-to-refresh arrives
- add an empty-state branch later
- bolt on retry, skeletons, pagination, and stale-content banners as separate booleans

That works for a sprint, then the ViewModel becomes a truth table nobody can hold in their head.

Typical failure modes:

- impossible combinations appear, like loading + error + empty at the same time
- UI regressions happen because one flag changes without the others
- tests turn into fragile assertion soup
- new product states feel expensive because every branch is implicit

## Modern approach

Now I prefer to model the screen around a small number of explicit states and transitions.

Instead of this:

```swift
final class PortfolioViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var showError = false
    @Published var hasLoadedOnce = false
    @Published var positions: [Position] = []
    @Published var errorMessage: String?
}
```

I would rather carry one state model with attached data:

```swift
struct PortfolioSnapshot: Equatable {
    let positions: [Position]
    let lastUpdated: Date
}

enum PortfolioScreenState: Equatable {
    case idle
    case loading
    case loaded(PortfolioSnapshot)
    case refreshing(PortfolioSnapshot)
    case empty
    case failed(message: String, lastSnapshot: PortfolioSnapshot?)
}
```

The code is not shorter, but the architecture is calmer.

The real gain is that every product conversation gets translated into a valid transition:

- idle -> loading
- loading -> loaded
- loaded -> refreshing
- refreshing -> failed(last good snapshot preserved)
- loaded -> empty if filters remove everything

That makes state ownership obvious. The View renders one state. The ViewModel decides transitions. The repository still just fetches data.

## Migration strategy

When I clean up a boolean-heavy screen, I do it in this order:

1. list every user-visible state the screen can actually be in
2. mark invalid combinations that should never coexist
3. replace the most coupled booleans with one enum and associated values
4. move transition logic into a few named methods instead of scattered property writes
5. update tests to assert state transitions, not individual flags

I do not try to invent a giant framework first. Usually one focused enum removes more chaos than a whole architecture rewrite.

## Production notes

A few heuristics have held up well for me:

- if I need three or more booleans to explain one screen, I probably need a state model
- if retry should preserve old content, I model that directly instead of hiding it in ad hoc flags
- if analytics depend on state transitions, explicit states make instrumentation much safer
- if designers care about nuanced loading/error/stale behavior, booleans usually collapse too much meaning

My rule now is simple: when a feature starts collecting flags, I stop adding conditionals and ask what state machine is trying to emerge.
