// 2026-08-12 — Swift Snippet: Bridge callbacks with AsyncStream
//
// I use this adapter when a callback-based SDK needs to feed a Swift concurrency
// pipeline. Keeping continuation ownership in one place makes cancellation explicit.

import Foundation

final class ReachabilityMonitor {
    private var handler: ((Bool) -> Void)?

    func start(_ handler: @escaping (Bool) -> Void) {
        self.handler = handler
    }

    func stop() {
        handler = nil
    }

    func simulateChange(isOnline: Bool) {
        handler?(isOnline)
    }
}

func connectivityEvents(from monitor: ReachabilityMonitor) -> AsyncStream<Bool> {
    AsyncStream { continuation in
        monitor.start { isOnline in
            continuation.yield(isOnline)
        }

        // A cancelled consumer must also release the SDK callback.
        continuation.onTermination = { @Sendable _ in
            monitor.stop()
        }
    }
}

@main
struct Demo {
    static func main() async {
        let monitor = ReachabilityMonitor()
        let events = connectivityEvents(from: monitor)

        let consumer = Task {
            for await isOnline in events {
                print("Online: \(isOnline)")
                break // This demo consumes one event; production code stays alive.
            }
        }

        monitor.simulateChange(isOnline: true)
        _ = await consumer.result
    }
}
