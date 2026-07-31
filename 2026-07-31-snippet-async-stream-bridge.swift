// AsyncStream lets me turn a callback-shaped SDK into code that obeys
// Swift concurrency cancellation. The termination hook matters: without it,
// leaving a `for await` loop can leave the underlying listener running.
import Foundation

protocol Cancellable { func cancel() }

protocol EventSource<Event> {
    associatedtype Event
    func start(
        onEvent: @escaping (Event) -> Void,
        onFinish: @escaping (Error?) -> Void
    ) -> any Cancellable
}

final class EventAdapter<Source: EventSource> {
    private let source: Source

    init(source: Source) { self.source = source }

    func events() -> AsyncThrowingStream<Source.Event, Error> {
        AsyncThrowingStream { continuation in
            let token = source.start(
                onEvent: { continuation.yield($0) },
                onFinish: { error in
                    if let error { continuation.finish(throwing: error) }
                    else { continuation.finish() }
                }
            )
            // Cancelling the Task now releases the SDK subscription too.
            continuation.onTermination = { _ in token.cancel() }
        }
    }
}

// Usage: for try await event in adapter.events() { render(event) }
