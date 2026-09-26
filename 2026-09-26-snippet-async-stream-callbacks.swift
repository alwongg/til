// AsyncStream: bridge a callback API into async/await
//
// I use this adapter at system boundaries so the rest of a feature can stay
// structured-concurrency native. Cancellation must travel back to the callback
// source; otherwise a dismissed screen can keep doing unnecessary work.

import Foundation

final class DownloadClient {
    func data(from url: URL, completion: @escaping (Result<Data, Error>) -> Void) -> URLSessionDataTask {
        let task = URLSession.shared.dataTask(with: url) { data, _, error in
            if let error {
                completion(.failure(error))
            } else if let data {
                completion(.success(data))
            } else {
                completion(.failure(URLError(.badServerResponse)))
            }
        }
        task.resume()
        return task
    }
}

func download(from url: URL, using client: DownloadClient) -> AsyncThrowingStream<Data, Error> {
    AsyncThrowingStream { continuation in
        let task = client.data(from: url) { result in
            switch result {
            case .success(let data):
                continuation.yield(data)
                continuation.finish()
            case .failure(let error):
                continuation.finish(throwing: error)
            }
        }

        // This closes the ownership loop when the consuming task is cancelled.
        continuation.onTermination = { _ in task.cancel() }
    }
}

func fetchAvatar(_ url: URL, client: DownloadClient) async throws -> Data {
    for try await data in download(from: url, using: client) { return data }
    throw URLError(.cannotDecodeContentData)
}
