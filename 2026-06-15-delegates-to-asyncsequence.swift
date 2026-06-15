/*
From Delegates to AsyncSequence for Event Streams

I still run into code that models a stream of values with a delegate, an array of callbacks,
or a pile of escaping closures. That style worked, but Swift's concurrency model gives me a
cleaner way to represent “many values over time” as an AsyncSequence.

What changed in my mental model:
- Legacy Swift: one-shot completion handlers everywhere, plus bespoke delegate protocols for streams.
- Modern Swift: async for one-shot work, AsyncSequence for streams, and actor isolation for shared state.
- Result: the shape of the API now tells me whether I'm awaiting one value or consuming many.

Migration strategy I use in production:
1. Keep the old delegate-based source at the edge.
2. Add an AsyncThrowingStream adapter instead of rewriting the whole feature.
3. Move consumers one by one from callback state machines to `for try await` loops.
4. When the async path is stable, delete the delegate surface from app-level code.

Production notes:
- I always wire `onTermination` so cancellation removes the delegate and avoids leaks.
- Buffering policy matters. Newest-only is often right for UI signals; unbounded is a footgun.
- I keep transport concerns at the adapter layer so features consume domain events, not SDK mechanics.
*/

import Foundation

struct Message: Sendable, Equatable {
    let id: UUID
    let body: String
}

enum MessageEvent: Sendable, Equatable {
    case connected
    case message(Message)
    case disconnected
}

protocol LegacyMessageClientDelegate: AnyObject {
    func clientDidConnect()
    func clientDidDisconnect(error: Error?)
    func clientDidReceiveMessage(_ message: Message)
}

final class LegacyMessageClient {
    weak var delegate: LegacyMessageClientDelegate?

    func connect() async {
        delegate?.clientDidConnect()
    }

    func simulateIncomingMessage(_ body: String) {
        delegate?.clientDidReceiveMessage(Message(id: UUID(), body: body))
    }

    func disconnect() {
        delegate?.clientDidDisconnect(error: nil)
    }
}

private final class DelegateProxy: LegacyMessageClientDelegate {
    let yield: @Sendable (MessageEvent) -> Void
    let finish: @Sendable (Error?) -> Void

    init(
        yield: @escaping @Sendable (MessageEvent) -> Void,
        finish: @escaping @Sendable (Error?) -> Void
    ) {
        self.yield = yield
        self.finish = finish
    }

    func clientDidConnect() {
        yield(.connected)
    }

    func clientDidDisconnect(error: Error?) {
        yield(.disconnected)
        finish(error)
    }

    func clientDidReceiveMessage(_ message: Message) {
        yield(.message(message))
    }
}

actor MessageStreamAdapter {
    private let client: LegacyMessageClient
    private var delegateProxy: DelegateProxy?

    init(client: LegacyMessageClient) {
        self.client = client
    }

    func events() -> AsyncThrowingStream<MessageEvent, Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(20)) { continuation in
            let proxy = DelegateProxy(
                yield: { event in
                    continuation.yield(event)
                },
                finish: { error in
                    if let error {
                        continuation.finish(throwing: error)
                    } else {
                        continuation.finish()
                    }
                }
            )

            delegateProxy = proxy
            client.delegate = proxy

            continuation.onTermination = { [weak client] _ in
                client?.delegate = nil
            }

            Task {
                await client.connect()
            }
        }
    }
}

struct MessageFeature {
    let adapter: MessageStreamAdapter

    func startConsuming() async throws -> [String] {
        var transcript: [String] = []

        for try await event in await adapter.events() {
            switch event {
            case .connected:
                transcript.append("connected")
            case .message(let message):
                transcript.append(message.body)
            case .disconnected:
                transcript.append("disconnected")
            }
        }

        return transcript
    }
}
