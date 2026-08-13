// AsyncStream: bridge a callback API into structured concurrency
//
// I use this adapter at system boundaries. The callback stays contained here;
// the rest of the feature can consume `for await` and own cancellation clearly.

import Foundation

final class ReachabilityMonitor {
    private var callback: ((Bool) -> Void)?

    func start(_ callback: @escaping (Bool) -> Void) {
        self.callback = callback
    }

    func stop() {
        callback = nil
    }
}

func connectivityUpdates(from monitor: ReachabilityMonitor) -> AsyncStream<Bool> {
    AsyncStream { continuation in
        monitor.start { isConnected in
            continuation.yield(isConnected)
        }

        // Cancellation must release the callback; otherwise the monitor can
        // keep a screen's task alive after the screen disappears.
        continuation.onTermination = { _ in
            monitor.stop()
        }
    }
}

@main
enum Demo {
    static func main() async {
        let monitor = ReachabilityMonitor()
        let task = Task {
            for await isConnected in connectivityUpdates(from: monitor) {
                print("Connected: \(isConnected)")
            }
        }
        task.cancel()
    }
}
