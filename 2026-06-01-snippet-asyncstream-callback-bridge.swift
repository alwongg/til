import Foundation

// I still inherit callback-based APIs in UIKit-heavy codebases.
// This bridge lets me expose them as AsyncStream without rewriting the world.
final class DownloadClient {
    typealias Completion = (Result<Data, Error>) -> Void

    func fetch(path: String, completion: @escaping Completion) {
        let workItem = DispatchWorkItem {
            completion(.success(Data(path.utf8)))
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }
}

func makeDataStream(
    paths: [String],
    client: DownloadClient
) -> AsyncStream<Result<Data, Error>> {
    AsyncStream { continuation in
        let group = DispatchGroup()

        for path in paths {
            group.enter()
            client.fetch(path: path) { result in
                continuation.yield(result)
                group.leave()
            }
        }

        group.notify(queue: .global()) {
            continuation.finish()
        }
    }
}

@main
struct DemoApp {
    static func main() async {
        let client = DownloadClient()

        for await result in makeDataStream(paths: ["users", "posts", "comments"], client: client) {
            switch result {
            case .success(let data):
                // I keep the bridge generic so the async caller can decode or fan out later.
                print(String(decoding: data, as: UTF8.self))
            case .failure(let error):
                print("error: \(error)")
            }
        }
    }
}
