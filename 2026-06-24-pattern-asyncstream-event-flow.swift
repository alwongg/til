import Foundation

// I use an AsyncStream-backed event bus when I want feature modules to react
// to domain events without depending on each other directly.
actor EventBus<Event: Sendable> {
    private var continuations: [UUID: AsyncStream<Event>.Continuation] = [:]

    func stream() -> AsyncStream<Event> {
        let id = UUID()
        return AsyncStream(bufferingPolicy: .bufferingNewest(10)) { continuation in
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id) }
            }
        }
    }

    func publish(_ event: Event) {
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    private func removeContinuation(_ id: UUID) {
        continuations.removeValue(forKey: id)
    }
}

enum CheckoutEvent: Sendable {
    case cartUpdated(itemCount: Int)
    case paymentSucceeded(orderID: String)
}

@main
struct Demo {
    static func main() async {
        let bus = EventBus<CheckoutEvent>()

        let analytics = Task {
            let stream = await bus.stream()
            for await event in stream {
                print("analytics:", event)
            }
        }

        let badgeUpdater = Task {
            let stream = await bus.stream()
            for await event in stream {
                if case let .cartUpdated(itemCount) = event {
                    print("badge count:", itemCount)
                }
            }
        }

        await bus.publish(.cartUpdated(itemCount: 3))
        await bus.publish(.paymentSucceeded(orderID: "A123"))

        analytics.cancel()
        badgeUpdater.cancel()
    }
}
