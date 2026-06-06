// I use AsyncStream when I need to pull an old callback API into structured concurrency without rewriting the whole dependency.
import Foundation

final class LegacyDownloader {
    typealias Completion = (Result<Data, Error>) -> Void

    func fetch(from url: URL, progress: @escaping (Double) -> Void, completion: @escaping Completion) {
        progress(0.25)
        progress(0.75)
        completion(.success(Data(url.absoluteString.utf8)))
    }
}

func progressStream(for url: URL, downloader: LegacyDownloader) -> AsyncThrowingStream<Double, Error> {
    AsyncThrowingStream { continuation in
        downloader.fetch(from: url) { value in
            continuation.yield(value)
        } completion: { result in
            switch result {
            case .success:
                continuation.finish()
            case .failure(let error):
                continuation.finish(throwing: error)
            }
        }

        // I always terminate the stream explicitly so the caller never waits forever on a legacy callback.
        continuation.onTermination = { _ in }
    }
}

func observeDownload() async {
    let downloader = LegacyDownloader()
    let url = URL(string: "https://example.com/export.json")!

    do {
        for try await progress in progressStream(for: url, downloader: downloader) {
            print("progress:", progress)
        }
    } catch {
        print("download failed:", error)
    }
}
