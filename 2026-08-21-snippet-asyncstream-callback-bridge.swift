import Foundation

protocol Cancellation {
    func cancel()
}

protocol LegacyTicker {
    func start(
        onValue: @escaping (Int) -> Void,
        onFinish: @escaping (Error?) -> Void
    ) -> any Cancellation
}

func tickerValues(from ticker: LegacyTicker) -> AsyncThrowingStream<Int, Error> {
    AsyncThrowingStream { continuation in
        let cancellation = ticker.start(
            onValue: { value in
                continuation.yield(value)
            },
            onFinish: { error in
                if let error {
                    continuation.finish(throwing: error)
                } else {
                    continuation.finish()
                }
            }
        )

        // Cancelling the consumer must stop the legacy producer too.
        continuation.onTermination = { _ in
            cancellation.cancel()
        }
    }
}

func consume(_ ticker: LegacyTicker) async throws {
    for try await value in tickerValues(from: ticker) {
        print("Received \(value)")
    }
}
