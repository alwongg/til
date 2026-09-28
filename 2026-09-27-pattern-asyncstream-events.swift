import Foundation

// I use a typed event stream when a feature has many producers but one clear UI consumer.
enum CheckoutEvent: Sendable, Equatable {
    case cartUpdated(itemCount: Int)
    case paymentSucceeded(orderID: String)
    case paymentFailed(message: String)
}

actor CheckoutEventBus {
    private var continuations: [UUID: AsyncStream<CheckoutEvent>.Continuation] = [:]

    func stream() -> AsyncStream<CheckoutEvent> {
        let id = UUID()
        return AsyncStream { continuation in
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id) }
            }
        }
    }

    func send(_ event: CheckoutEvent) {
        continuations.values.forEach { $0.yield(event) }
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }
}

@MainActor
final class CheckoutViewModel {
    private(set) var status = "Ready"

    func observe(_ bus: CheckoutEventBus) async {
        for await event in await bus.stream() {
            switch event {
            case .cartUpdated(let count): status = "\(count) items"
            case .paymentSucceeded(let id): status = "Order \(id) confirmed"
            case .paymentFailed(let message): status = message
            }
        }
    }
}
