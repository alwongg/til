// Today I’m turning a delegate-style callback into an AsyncSequence.
// The key production detail is wiring cancellation back to the legacy API;
// otherwise a cancelled Swift task can leave the old request alive.

import Foundation

protocol LegacyFeedLoading {
    func load(completion: @escaping (Result<[String], Error>) -> Void)
    func cancel()
}

extension LegacyFeedLoading {
    func updates() -> AsyncThrowingStream<[String], Error> {
        AsyncThrowingStream { continuation in
            load { result in
                switch result {
                case .success(let items):
                    continuation.yield(items)
                    continuation.finish()
                case .failure(let error):
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                // Cancellation must reach the callback API, not just the consumer.
                self.cancel()
            }
        }
    }
}

func refresh(using loader: some LegacyFeedLoading) async throws -> [String] {
    for try await items in loader.updates() {
        return items
    }
    return [] // A legacy API that finishes without a value maps to an empty feed.
}
