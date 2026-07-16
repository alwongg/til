import Foundation

// I use AsyncStream to turn callback lifecycles into structured async iteration.
final class LocationFeed: @unchecked Sendable {
    private var handler: ((String) -> Void)?

    func start(_ handler: @escaping (String) -> Void) {
        self.handler = handler
    }

    func stop() {
        handler = nil
    }

    func simulate(_ value: String) {
        handler?(value)
    }
}

extension LocationFeed {
    func updates() -> AsyncStream<String> {
        AsyncStream { continuation in
            start { value in
                continuation.yield(value)
            }

            continuation.onTermination = { [weak self] _ in
                // Cancellation must release the callback, not just stop the loop.
                self?.stop()
            }
        }
    }
}

func observe(_ feed: LocationFeed) async {
    for await location in feed.updates() {
        print("Latest: \(location)")
    }
}
