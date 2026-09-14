import Foundation

// I wrap callback-style observation in AsyncStream so cancellation has one clear owner.
final class LegacyReachabilityMonitor: @unchecked Sendable {
    typealias Handler = @Sendable (Bool) -> Void

    private var handler: Handler?

    func start(_ handler: @escaping Handler) {
        self.handler = handler
    }

    func stop() {
        handler = nil
    }

    func simulateChange(isOnline: Bool) {
        handler?(isOnline)
    }
}

func reachabilityEvents(
    monitor: LegacyReachabilityMonitor
) -> AsyncStream<Bool> {
    AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
        monitor.start { isOnline in
            // Keeping only the newest state prevents a slow UI consumer from replaying stale states.
            continuation.yield(isOnline)
        }

        continuation.onTermination = { @Sendable _ in
            // This is the important bridge: task cancellation tears down the legacy observer.
            monitor.stop()
        }
    }
}

@main
struct Demo {
    static func main() async {
        let monitor = LegacyReachabilityMonitor()
        let stream = reachabilityEvents(monitor: monitor)

        let observer = Task {
            for await isOnline in stream {
                print("Online: \(isOnline)")
                break // A real feature would update state until its task is cancelled.
            }
        }

        monitor.simulateChange(isOnline: true)
        _ = await observer.result
    }
}
