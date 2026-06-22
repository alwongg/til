import Foundation

// I still run into callback-based APIs that are too small to justify a full rewrite.
// My move is to wrap them once, then keep the rest of the feature in async/await land.

final class ReachabilityMonitor {
    typealias Handler = (Bool) -> Void
    private var handlers: [UUID: Handler] = [:]

    func observe(_ handler: @escaping Handler) -> UUID {
        let id = UUID()
        handlers[id] = handler
        return id
    }

    func removeObserver(_ id: UUID) {
        handlers.removeValue(forKey: id)
    }

    func simulate(status: Bool) {
        handlers.values.forEach { $0(status) }
    }
}

extension ReachabilityMonitor {
    func statuses() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let token = observe { isReachable in
                continuation.yield(isReachable)
            }

            continuation.onTermination = { [weak self] _ in
                self?.removeObserver(token)
            }
        }
    }
}

@main
enum Demo {
    static func main() async {
        let monitor = ReachabilityMonitor()

        let task = Task {
            var iterator = monitor.statuses().makeAsyncIterator()
            while let isReachable = await iterator.next() {
                print("reachable:", isReachable)
                if isReachable { break }
            }
        }

        monitor.simulate(status: false)
        monitor.simulate(status: true)
        _ = await task.result
    }
}
