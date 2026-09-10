import Foundation

enum CheckoutEvent: Sendable {
    case submitted(orderID: UUID)
    case paymentFailed(orderID: UUID, message: String)
    case completed(orderID: UUID)
}

actor CheckoutEventBus {
    private var subscribers: [UUID: AsyncStream<CheckoutEvent>.Continuation] = [:]

    func events() -> AsyncStream<CheckoutEvent> {
        let subscriberID = UUID()

        return AsyncStream { continuation in
            // A screen owns its subscription; cancellation removes only that screen.
            subscribers[subscriberID] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeSubscriber(subscriberID) }
            }
        }
    }

    func publish(_ event: CheckoutEvent) {
        subscribers.values.forEach { $0.yield(event) }
    }

    private func removeSubscriber(_ id: UUID) {
        subscribers[id] = nil
    }
}

@MainActor
final class CheckoutViewModel {
    private(set) var status = "Ready"
    private var observer: Task<Void, Never>?

    init(events: CheckoutEventBus) {
        observer = Task {
            for await event in await events.events() {
                switch event {
                case .submitted: status = "Processing payment…"
                case .paymentFailed(_, let message): status = message
                case .completed: status = "Order complete"
                }
            }
        }
    }

    deinit { observer?.cancel() }
}
