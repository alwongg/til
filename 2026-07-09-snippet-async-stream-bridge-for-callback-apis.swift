import Foundation

// I reach for AsyncThrowingStream when an SDK still talks in callbacks,
// but the rest of my feature wants structured concurrency semantics.
// The bridge keeps cancellation and completion in one place instead of
// scattering delegate closures across a view model.

final class SocketClient {
    var onMessage: ((String) -> Void)?
    var onDisconnect: ((Error?) -> Void)?

    func messages() -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            onMessage = { continuation.yield($0) }
            onDisconnect = { error in
                if let error {
                    continuation.finish(throwing: error)
                } else {
                    continuation.finish()
                }
            }

            continuation.onTermination = { [weak self] _ in
                self?.onMessage = nil
                self?.onDisconnect = nil
            }
        }
    }
}

final class ChatViewModel {
    private let client: SocketClient
    private(set) var recentMessages: [String] = []

    init(client: SocketClient) {
        self.client = client
    }

    func bind() async {
        do {
            for try await message in client.messages() {
                recentMessages.append(message)
            }
        } catch {
            // This is where I would trigger reconnect/backoff policy.
        }
    }
}
