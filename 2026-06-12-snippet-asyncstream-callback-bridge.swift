import Foundation

enum ConnectionStatus: Sendable {
    case connecting
    case connected
    case disconnected
}

final class LegacyReachabilityMonitor {
    private var handler: (@Sendable (ConnectionStatus) -> Void)?

    func start(handler: @escaping @Sendable (ConnectionStatus) -> Void) {
        self.handler = handler

        // When I inherit a callback API, I bridge it first so the rest of the feature can stay async/await-native.
        handler(.connecting)
        handler(.connected)
        handler(.disconnected)
    }

    func stop() {
        handler = nil
    }
}

func statusStream(from monitor: LegacyReachabilityMonitor) -> AsyncStream<ConnectionStatus> {
    AsyncStream { continuation in
        monitor.start { status in
            continuation.yield(status)
            if case .disconnected = status {
                continuation.finish()
            }
        }

        continuation.onTermination = { _ in
            // I always hook cleanup here so cancellation tears down the legacy observer path too.
            monitor.stop()
        }
    }
}

@main
struct AsyncStreamCallbackBridgeDemo {
    static func main() async {
        let monitor = LegacyReachabilityMonitor()

        for await status in statusStream(from: monitor) {
            print("status:", status)
        }
    }
}
