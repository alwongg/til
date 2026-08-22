import Foundation

/// I use AsyncStream at callback boundaries so the rest of my feature can stay
/// structured-concurrent. The cancellation handler is the important part: it
/// releases the legacy observer when the consuming task goes away.
final class ReachabilityMonitor {
    typealias Token = UUID
    private var handlers: [Token: (Bool) -> Void] = [:]

    @discardableResult
    func observe(_ handler: @escaping (Bool) -> Void) -> Token {
        let token = UUID()
        handlers[token] = handler
        return token
    }

    func removeObserver(_ token: Token) {
        handlers[token] = nil
    }

    func publish(isReachable: Bool) {
        handlers.values.forEach { $0(isReachable) }
    }
}

func reachabilityUpdates(from monitor: ReachabilityMonitor) -> AsyncStream<Bool> {
    AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
        let token = monitor.observe { isReachable in
            continuation.yield(isReachable)
        }

        // Without this, a cancelled screen can leave a callback retained forever.
        continuation.onTermination = { _ in
            monitor.removeObserver(token)
        }
    }
}

@main
struct Demo {
    static func main() async {
        let monitor = ReachabilityMonitor()
        let task = Task {
            for await isReachable in reachabilityUpdates(from: monitor) {
                print("Reachable: \(isReachable)")
                break
            }
        }

        monitor.publish(isReachable: true)
        await task.value
    }
}
