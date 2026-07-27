import Foundation

// I wrap callback-style APIs once, so the rest of the feature can use structured concurrency.
protocol ReachabilityDelegate: AnyObject {
    func reachabilityDidChange(isOnline: Bool)
}

final class LegacyReachability {
    weak var delegate: ReachabilityDelegate?

    func simulateChange(isOnline: Bool) {
        delegate?.reachabilityDidChange(isOnline: isOnline)
    }
}

final class ReachabilityEvents: ReachabilityDelegate {
    private let manager: LegacyReachability
    private var continuation: AsyncStream<Bool>.Continuation?

    init(manager: LegacyReachability) {
        self.manager = manager
    }

    func makeStream() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            self.continuation = continuation
            self.manager.delegate = self
            continuation.onTermination = { [weak self] _ in
                self?.manager.delegate = nil // Stop retaining the bridge after the consumer leaves.
                self?.continuation = nil
            }
        }
    }

    func reachabilityDidChange(isOnline: Bool) {
        continuation?.yield(isOnline)
    }
}

@main
struct Demo {
    static func main() async {
        let legacy = LegacyReachability()
        let events = ReachabilityEvents(manager: legacy)
        let task = Task { for await online in events.makeStream() { print("Online: \(online)") } }
        legacy.simulateChange(isOnline: true)
        task.cancel()
    }
}
