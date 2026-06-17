import Foundation

/*
 Tip: Using defer to make cleanup impossible to forget

 I reach for `defer` when a function has multiple exits but exactly one cleanup rule.
 The win is not fewer lines. The win is that future me can add a new `guard` or `throw`
 without accidentally leaving loading state, file handles, or tracing spans open.
*/

final class LoadingGate {
    private(set) var isLoading = false

    func begin() { isLoading = true }
    func end() { isLoading = false }
}

enum ProfileLoadError: Error {
    case missingURL
    case badStatus(Int)
}

struct ProfileLoader {
    let gate: LoadingGate

    func load(from url: URL?) async throws -> Data {
        gate.begin()
        defer { gate.end() } // Why: every exit path closes the loading gate.

        guard let url else { throw ProfileLoadError.missingURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard 200..<300 ~= statusCode else { throw ProfileLoadError.badStatus(statusCode) }

        return data
    }
}
