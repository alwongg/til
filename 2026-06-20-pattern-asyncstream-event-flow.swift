# Slot 4/4 — Architecture Pattern
# Event-driven flow with AsyncStream

I reach for `AsyncStream` when I want feature boundaries to stay decoupled without inventing a full reactive framework. The useful shift is treating events as a lightweight domain API: producers emit facts, consumers decide how to react, and nothing needs to know who is listening.

```swift
import Foundation

enum AppEvent {
    case userSignedIn(id: String)
    case profileRefreshed
}

final class EventBus {
    private var continuation: AsyncStream<AppEvent>.Continuation?

    lazy var stream: AsyncStream<AppEvent> = {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }()

    func send(_ event: AppEvent) {
        continuation?.yield(event)
    }
}

final class SessionCoordinator {
    private let bus: EventBus

    init(bus: EventBus) {
        self.bus = bus
    }

    func start() async {
        for await event in bus.stream {
            switch event {
            case .userSignedIn(let id):
                print("Warm profile cache for \(id)")
            case .profileRefreshed:
                print("Refresh visible UI state")
            }
        }
    }
}

@main
struct DemoApp {
    static func main() async {
        let bus = EventBus()
        let coordinator = SessionCoordinator(bus: bus)

        Task { await coordinator.start() }
        bus.send(.userSignedIn(id: "42"))
        bus.send(.profileRefreshed)
    }
}
```

Why I like it in production:
- The publisher side stays tiny. A feature can emit domain events without importing UI or navigation types.
- The consumer side owns coordination. That makes it easier to test sequencing and side effects.
- `AsyncStream` works especially well when I already have Swift concurrency and want structured cancellation instead of bolting on another abstraction.

My guardrail: keep the event enum small and meaningful. If it starts turning into a global dump of app state changes, I split the stream by domain instead of letting one bus become a hidden dependency graph.
