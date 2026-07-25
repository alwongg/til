// AsyncStream bridges a callback-based API into an async sequence.
// I keep cancellation on both sides so ending the consumer also stops the legacy work.

import Foundation

final class LegacyReachability {
    private var handler: ((Bool) -> Void)?

    func start(_ handler: @escaping (Bool) -> Void) { self.handler = handler }
    func stop() { handler = nil }
}

extension LegacyReachability {
    func statusUpdates() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            start { isOnline in
                continuation.yield(isOnline)
            }

            continuation.onTermination = { [weak self] _ in
                // A cancelled view task must not leave the callback retained.
                self?.stop()
            }
        }
    }
}

@main
struct Demo {
    static func main() async {
        let reachability = LegacyReachability()

        let observer = Task {
            for await isOnline in reachability.statusUpdates() {
                print("Network is \(isOnline ? "online" : "offline")")
            }
        }

        observer.cancel()
    }
}
