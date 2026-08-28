// Production Patterns at Scale: Generation-Guarded Async Loading
//
// Legacy approach
// I used to let each cell own a Task and assign its result when it finished.
// Fast scrolling made an old request overwrite the image for a reused cell.
//
// Modern approach
// I give each request a generation token. Only the latest generation may publish.
// Cancellation saves work; the token preserves correctness when cancellation races.

import Foundation

actor ImagePayloadLoader {
    private var generation = 0
    private var task: Task<Data, Error>?

    func load(_ url: URL) async throws -> Data {
        generation += 1
        let requestGeneration = generation

        task?.cancel()
        let newTask = Task { () throws -> Data in
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            return data
        }
        task = newTask

        let data = try await newTask.value
        try Task.checkCancellation()
        guard requestGeneration == generation else {
            throw CancellationError()
        }
        return data
    }
}

// Migration strategy
// 1. Put the loader behind my existing image-service protocol.
// 2. Add generation guards before replacing every call site with async/await.
// 3. Instrument cancellations and stale-result drops during a staged rollout.
//
// Production notes
// I still cache decoded images separately. This guard is about ownership of the
// latest UI request, not caching. A token check is worth keeping because Task
// cancellation is cooperative: a request can finish just as I cancel it.
