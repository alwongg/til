import Foundation

// Snippet: AsyncStream bridging callbacks
// I use this when a legacy API emits progress through callbacks but the rest of my feature has moved to async/await.
// Wrapping the boundary in AsyncThrowingStream lets me keep the migration small and gives the caller a clean `for try await` loop.

struct ProgressEvent: Sendable {
    let completed: Int
    let total: Int
}

final class DownloadEmitter {
    func stream(total: Int) -> AsyncThrowingStream<ProgressEvent, Error> {
        AsyncThrowingStream { continuation in
            start(
                total: total,
                onProgress: { completed in
                    continuation.yield(.init(completed: completed, total: total))
                },
                onComplete: { result in
                    switch result {
                    case .success:
                        continuation.finish()
                    case .failure(let error):
                        continuation.finish(throwing: error)
                    }
                }
            )
        }
    }

    private func start(
        total: Int,
        onProgress: @escaping @Sendable (Int) -> Void,
        onComplete: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        for step in 1...total {
            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(step * 120)) {
                onProgress(step)
                if step == total {
                    onComplete(.success(()))
                }
            }
        }
    }
}

func captureProgress() async throws -> [String] {
    let emitter = DownloadEmitter()
    var snapshots: [String] = []

    for try await event in emitter.stream(total: 3) {
        snapshots.append("\(event.completed)/\(event.total)")
    }

    return snapshots
}
