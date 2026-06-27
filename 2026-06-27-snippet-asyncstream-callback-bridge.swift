import Foundation

/*
 AsyncThrowingStream is my favorite way to put a clean async boundary
 around an old callback API. I keep the bridge tiny, preserve cancellation,
 and make progress events explicit so the calling code can stay structured.
 */

protocol Cancellable: AnyObject {
    func cancel()
}

protocol Downloading {
    @discardableResult
    func fetch(
        _ url: URL,
        progress: @escaping @Sendable (Double) -> Void,
        completion: @escaping @Sendable (Result<Data, Error>) -> Void
    ) -> Cancellable
}

enum DownloadEvent: Sendable {
    case progress(Double)
    case finished(Data)
}

func downloadStream(
    from url: URL,
    using downloader: Downloading
) -> AsyncThrowingStream<DownloadEvent, Error> {
    AsyncThrowingStream { continuation in
        let request = downloader.fetch(
            url,
            progress: { continuation.yield(.progress($0)) },
            completion: { result in
                switch result {
                case .success(let data):
                    continuation.yield(.finished(data))
                    continuation.finish()
                case .failure(let error):
                    continuation.finish(throwing: error)
                }
            }
        )

        continuation.onTermination = { @Sendable _ in
            request.cancel()
        }
    }
}

struct AvatarLoader {
    let downloader: Downloading

    func load(from url: URL) async throws -> Data {
        var finalData = Data()

        for try await event in downloadStream(from: url, using: downloader) {
            switch event {
            case .progress(let fraction):
                // Good spot to forward progress into state/UI.
                _ = fraction
            case .finished(let data):
                finalData = data
            }
        }

        return finalData
    }
}
