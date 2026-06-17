import Foundation

/// Swift Snippet: AsyncStream bridging callbacks
///
/// I still run into SDKs that expose progress and completion as callbacks.
/// When the rest of my feature is already async/await, I prefer to bridge that
/// legacy shape once and keep the call site structured.

enum DownloadEvent: Sendable {
    case progress(Double)
    case finished(Data)
}

final class LegacyDownloader {
    typealias ProgressHandler = @Sendable (Double) -> Void
    typealias CompletionHandler = @Sendable (Result<Data, Error>) -> Void

    private var workItem: DispatchWorkItem?

    func start(url: URL, progress: @escaping ProgressHandler, completion: @escaping CompletionHandler) {
        let item = DispatchWorkItem {
            progress(0.25)
            progress(0.65)
            progress(1.0)
            completion(.success(Data(url.absoluteString.utf8)))
        }
        workItem = item
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1, execute: item)
    }

    func cancel() {
        workItem?.cancel()
    }
}

func downloadEvents(url: URL, client: LegacyDownloader) -> AsyncThrowingStream<DownloadEvent, Error> {
    AsyncThrowingStream { continuation in
        client.start(url: url) { progress in
            continuation.yield(.progress(progress))
        } completion: { result in
            switch result {
            case .success(let data):
                continuation.yield(.finished(data))
                continuation.finish()
            case .failure(let error):
                continuation.finish(throwing: error)
            }
        }

        continuation.onTermination = { _ in
            client.cancel()
        }
    }
}
