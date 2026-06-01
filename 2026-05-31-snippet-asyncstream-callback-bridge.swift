import Foundation

final class LegacyStatusEmitter {
    var onStatus: ((String) -> Void)?

    func start() {
        ["connecting", "syncing", "ready"].enumerated().forEach { index, value in
            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(index * 200)) {
                self.onStatus?(value)
            }
        }
    }

    func stop() {
        onStatus = nil
    }
}

extension LegacyStatusEmitter {
    func stream() -> AsyncStream<String> {
        AsyncStream { continuation in
            onStatus = { continuation.yield($0) }
            continuation.onTermination = { [weak self] _ in self?.stop() }
            start()
        }
    }
}

let emitter = LegacyStatusEmitter()
let task = Task {
    for await status in emitter.stream().prefix(3) {
        print("status=\(status)")
    }
}

try await task.value

// I reach for AsyncStream when I need old callback code to behave like the rest
// of my structured concurrency stack. It gives me cancellation, composition,
// and a clean boundary for eventually deleting the legacy API.