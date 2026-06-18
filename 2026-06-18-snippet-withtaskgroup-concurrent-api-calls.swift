import Foundation

struct APIClient {
    let session: URLSession = .shared

    func fetch(_ url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    func fetchAll(_ urls: [URL]) async throws -> [URL: Data] {
        try await withThrowingTaskGroup(of: (URL, Data).self) { group in
            for url in urls {
                group.addTask { [self] in
                    // Each child task owns one request, so failures stay localized.
                    (url, try await fetch(url))
                }
            }

            var payloads: [URL: Data] = [:]
            for try await (url, data) in group {
                payloads[url] = data
            }
            return payloads
        }
    }
}
