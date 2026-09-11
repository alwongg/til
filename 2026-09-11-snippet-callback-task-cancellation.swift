import Foundation

/// The box makes the cancellation token safe to share between the operation
/// and its cancellation handler while I bridge a legacy callback API.
final class CancellationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var token: UUID?

    func store(_ token: UUID) {
        lock.lock(); defer { lock.unlock() }
        self.token = token
    }

    func take() -> UUID? {
        lock.lock(); defer { lock.unlock() }
        return token
    }
}

final class LegacyProfileClient {
    typealias Completion = (Result<String, Error>) -> Void

    @discardableResult
    func fetchProfile(id: String, completion: @escaping Completion) -> UUID {
        let token = UUID()
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            completion(.success("profile:\(id)"))
        }
        return token
    }

    func cancel(_ token: UUID) {
        // The real client would cancel its URLSession task here.
    }
}

extension LegacyProfileClient {
    func profile(id: String) async throws -> String {
        let box = CancellationBox()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let token = fetchProfile(id: id) { result in
                    continuation.resume(with: result)
                }
                box.store(token)
            }
        } onCancel: {
            if let token = box.take() { cancel(token) }
        }
    }
}

func loadProfile(client: LegacyProfileClient) async throws -> String {
    try await client.profile(id: "42")
}
