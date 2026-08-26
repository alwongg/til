// 2026-08-26 — Bridging callbacks into AsyncStream
//
// When I inherit a callback API, I convert it at the boundary instead of leaking
// completion handlers through the rest of the feature. Cancellation must also
// remove the underlying observer, otherwise a dismissed screen can keep receiving events.

import Foundation

final class EventSource<Value> {
    typealias Handler = (Value) -> Void
    private var handlers: [UUID: Handler] = [:]

    func observe(_ handler: @escaping Handler) -> UUID {
        let token = UUID()
        handlers[token] = handler
        return token
    }

    func removeObserver(_ token: UUID) {
        handlers[token] = nil
    }

    func emit(_ value: Value) {
        handlers.values.forEach { $0(value) }
    }
}

extension EventSource {
    func stream() -> AsyncStream<Value> {
        AsyncStream { continuation in
            let token = observe { continuation.yield($0) }
            continuation.onTermination = { [weak self] _ in
                self?.removeObserver(token)
            }
        }
    }
}

@main
struct Demo {
    static func main() async {
        let source = EventSource<Int>()
        let task = Task {
            for await value in source.stream() {
                print("Received: \(value)")
                break
            }
        }

        source.emit(42)
        _ = await task.result
    }
}
