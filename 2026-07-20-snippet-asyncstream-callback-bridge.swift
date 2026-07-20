// AsyncStream: bridge a callback API into structured concurrency
//
// I use this adapter at the boundary of a legacy SDK. The rest of the feature
// can `for await` values, cancel naturally, and never retain the delegate forever.

import Foundation

protocol ReachabilityDelegate: AnyObject {
    func reachabilityDidChange(isOnline: Bool)
}

final class LegacyReachability {
    weak var delegate: ReachabilityDelegate?
    func start() { /* SDK begins delivering changes */ }
    func stop() { /* SDK stops its callback source */ }
}

final class ReachabilityStream: NSObject, ReachabilityDelegate {
    private let legacy: LegacyReachability
    private var continuation: AsyncStream<Bool>.Continuation?

    init(legacy: LegacyReachability) {
        self.legacy = legacy
    }

    func updates() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            self.continuation = continuation
            self.legacy.delegate = self
            self.legacy.start()

            // Cancellation must tear down the callback source, not only the task.
            continuation.onTermination = { [weak self] _ in
                self?.legacy.stop()
                self?.legacy.delegate = nil
                self?.continuation = nil
            }
        }
    }

    func reachabilityDidChange(isOnline: Bool) {
        continuation?.yield(isOnline)
    }
}

func observe(_ stream: ReachabilityStream) async {
    for await isOnline in stream.updates() {
        print("Online: \(isOnline)")
    }
}
