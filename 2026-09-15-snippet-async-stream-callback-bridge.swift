import Foundation

final class LocationManager: NSObject {
    private var continuation: AsyncThrowingStream<String, Error>.Continuation?

    lazy var updates: AsyncThrowingStream<String, Error> = {
        AsyncThrowingStream { [weak self] continuation in
            self?.continuation = continuation
            // Clearing this prevents a stale stream from receiving future callbacks.
            continuation.onTermination = { [weak self] _ in
                self?.continuation = nil
            }
        }
    }()

    func didReceiveLocation(_ name: String) {
        continuation?.yield(name)
    }

    func didFail(_ error: Error) {
        continuation?.finish(throwing: error)
        continuation = nil
    }

    func stopUpdates() {
        continuation?.finish()
        continuation = nil
    }
}

func observe(_ manager: LocationManager) async throws {
    for try await location in manager.updates {
        print("Persisting location: \(location)")
    }
}
