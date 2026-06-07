# Why I Keep the Composition Root at the App Edge

I’ve learned that a lot of iOS architectural pain doesn’t come from SwiftUI vs UIKit or TCA vs MVVM. It comes from where object graphs get assembled.

When dependency creation leaks into views, coordinators, feature models, and random convenience initializers, the codebase starts to feel productive right up until I need to test, replace, or reason about anything. My rule now is simple: I want the composition root close to the app edge, and I want features to receive dependencies instead of discovering them.

## Legacy approach

This is the shape I usually regret a few months later:

```swift
import Foundation
import SwiftUI

final class APIClient {
    func loadTimeline() async throws -> [String] {
        ["Ship feature", "Fix bug", "Review PR"]
    }
}

final class AnalyticsTracker {
    func track(_ event: String) {
        print("Tracked: \(event)")
    }
}

@MainActor
final class TimelineViewModel: ObservableObject {
    @Published private(set) var items: [String] = []

    private let apiClient = APIClient()
    private let tracker = AnalyticsTracker()

    func load() async {
        do {
            items = try await apiClient.loadTimeline()
            tracker.track("timeline_loaded")
        } catch {
            tracker.track("timeline_failed")
        }
    }
}

struct TimelineView: View {
    @StateObject private var viewModel = TimelineViewModel()

    var body: some View {
        List(viewModel.items, id: \.self) { item in
            Text(item)
        }
        .task {
            await viewModel.load()
        }
    }
}
```

Nothing here looks outrageous, which is exactly why this pattern spreads:
- the view model silently decides which concrete services exist
- tests need invasive workarounds because dependencies are hidden
- feature behavior gets coupled to construction details
- swapping environments becomes a scavenger hunt

## Modern approach

I prefer one assembly boundary near the app edge and plain dependency injection inside the feature.

```swift
import Foundation
import SwiftUI

protocol TimelineLoading: Sendable {
    func loadTimeline() async throws -> [String]
}

protocol EventTracking: Sendable {
    func track(_ event: String)
}

struct LiveTimelineLoader: TimelineLoading {
    func loadTimeline() async throws -> [String] {
        ["Ship feature", "Fix bug", "Review PR"]
    }
}

struct LiveEventTracker: EventTracking {
    func track(_ event: String) {
        print("Tracked: \(event)")
    }
}

@MainActor
final class TimelineViewModel: ObservableObject {
    @Published private(set) var items: [String] = []

    private let loader: any TimelineLoading
    private let tracker: any EventTracking

    init(loader: any TimelineLoading, tracker: any EventTracking) {
        self.loader = loader
        self.tracker = tracker
    }

    func load() async {
        do {
            items = try await loader.loadTimeline()
            tracker.track("timeline_loaded")
        } catch {
            tracker.track("timeline_failed")
        }
    }
}

struct TimelineScreen: View {
    @StateObject private var viewModel: TimelineViewModel

    init(viewModel: @autoclosure @escaping () -> TimelineViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        List(viewModel.items, id: \.self) { item in
            Text(item)
        }
        .task {
            await viewModel.load()
        }
    }
}

struct AppContainer {
    let timelineLoader: any TimelineLoading
    let tracker: any EventTracking

    static let live = AppContainer(
        timelineLoader: LiveTimelineLoader(),
        tracker: LiveEventTracker()
    )
}

@main
struct DemoApp: App {
    private let container = AppContainer.live

    var body: some Scene {
        WindowGroup {
            TimelineScreen(
                viewModel: TimelineViewModel(
                    loader: container.timelineLoader,
                    tracker: container.tracker
                )
            )
        }
    }
}
```

The important shift isn’t “use a container.” It’s that construction happens once, near the application boundary, and feature code stays focused on behavior.

## Migration strategy

The way I usually move a real app toward this is deliberately boring:

1. Pick one feature with obvious dependency sprawl.
2. Convert concrete service references in the view model or presenter into injected protocols or small concrete abstractions.
3. Add a lightweight app container or assembly type at the scene/app/coordinator boundary.
4. Move object creation outward without changing the feature’s runtime behavior.
5. Only after the seam exists, improve tests and environment overrides.

That order matters. If I start by introducing a giant DI framework, I can end up moving complexity around instead of reducing it.

## Production notes

- I keep the composition root near `App`, `Scene`, or the top-level coordinator because that’s where environment choice actually belongs.
- I avoid letting SwiftUI previews build half the production graph implicitly. Previews get their own tiny containers or explicit mocks.
- A service locator can look convenient, but it usually reintroduces hidden coupling under a nicer name.
- The smaller the feature dependency surface, the easier it is to migrate architecture later without rewriting business logic.
- I care less about which DI style a codebase uses than whether dependency ownership is obvious in five minutes.

The payoff is that features stop being miniature app launchers. They become units I can read, test, and replace without tracing construction logic across the codebase.
