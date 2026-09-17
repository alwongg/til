import Foundation

// I use this adapter when a callback-based dependency needs to feed a
// cancellation-aware async loop instead of leaking its callback into a view model.
final class ReachabilityMonitor {
    private var handler: ((Bool) -> Void)?

    func start(_ handler: @escaping (Bool) -> Void) {
        self.handler = handler
    }

    func stop() {
        handler = nil
    }
}

extension ReachabilityMonitor {
    func updates() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            start { isReachable in
                continuation.yield(isReachable)
            }

            continuation.onTermination = { [weak self] _ in
                // Stopping here prevents a dismissed screen from retaining the monitor.
                self?.stop()
            }
        }
    }
}

@MainActor
final class ConnectionViewModel {
    private let monitor: ReachabilityMonitor
    private(set) var isOnline = false

    init(monitor: ReachabilityMonitor) {
        self.monitor = monitor
    }

    func observeConnection() async {
        for await value in monitor.updates() {
            isOnline = value
        }
    }
}
