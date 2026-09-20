import Foundation

// I wrap callback APIs at the boundary so the rest of the feature stays
// structured-concurrency native and cancellation has one obvious owner.
struct DownloadProgress: Sendable {
    let completed: Int
    let total: Int
}

protocol LegacyDownloader: AnyObject {
    func start(onProgress: @escaping (Int, Int) -> Void,
               onFinish: @escaping (Error?) -> Void)
    func cancel()
}

func progressStream(from downloader: LegacyDownloader) -> AsyncThrowingStream<DownloadProgress, Error> {
    AsyncThrowingStream { continuation in
        downloader.start(
            onProgress: { completed, total in
                continuation.yield(DownloadProgress(completed: completed, total: total))
            },
            onFinish: { error in
                if let error { continuation.finish(throwing: error) }
                else { continuation.finish() }
            }
        )

        // Cancellation must reach the legacy work; otherwise a dismissed screen
        // can leave a request alive and keep delivering callbacks.
        continuation.onTermination = { _ in downloader.cancel() }
    }
}

func observe(_ downloader: LegacyDownloader) async throws {
    for try await progress in progressStream(from: downloader) {
        let percent = progress.total == 0 ? 0 : progress.completed * 100 / progress.total
        print("Download: \(percent)%")
    }
}
