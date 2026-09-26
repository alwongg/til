import Foundation

// Quick Concept: Continuations must own their cancellation boundary
//
// I treat a continuation bridge as a tiny lifecycle adapter, not a convenience
// wrapper. The legacy operation remains responsible for producing values; the
// Swift task remains responsible for ending observation.

protocol Cancellable {
    func cancel()
}

final class LegacyTicker {
    func start(_ receive: @escaping @Sendable (Int) -> Void) -> Cancellable {
        TickerToken(receive: receive)
    }
}

private final class TickerToken: Cancellable, @unchecked Sendable {
    private let receive: @Sendable (Int) -> Void

    init(receive: @escaping @Sendable (Int) -> Void) {
        self.receive = receive
    }

    func cancel() {
        // Cancel the underlying callback source here. Keeping this ownership
        // close to the bridge prevents a Swift task from leaking work behind it.
    }
}

func tickerValues(from ticker: LegacyTicker) -> AsyncStream<Int> {
    AsyncStream { continuation in
        let token = ticker.start { value in
            continuation.yield(value)
        }

        continuation.onTermination = { _ in
            token.cancel()
        }
    }
}

// Migration strategy:
// 1. Wrap one callback API at its boundary, rather than scattering continuations.
// 2. Make cancellation deterministic through onTermination.
// 3. Keep buffering and error policy explicit as the stream contract evolves.
//
// Production note: If callbacks can outlive the screen, use AsyncThrowingStream
// when failures matter and choose a buffering policy intentionally. I also test
// cancellation: dropping the consuming task must cancel the legacy token.
