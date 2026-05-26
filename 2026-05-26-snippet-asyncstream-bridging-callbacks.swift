import Foundation

// 2026-05-26 — Swift Snippet
// Title: AsyncStream bridging callbacks
//
// When I inherit callback-heavy APIs, I like wrapping them in AsyncStream first.
// That lets the rest of the feature stay in structured concurrency instead of
// spreading escaping closures through every layer.

final class DownloadMonitor {
    var onProgress: ((Double) -> Void)?

    func simulateDownload() {
        for step in 1...5 {
            onProgress?(Double(step) / 5.0)
        }
        onProgress?(1.0)
    }
}

func progressStream(from monitor: DownloadMonitor) -> AsyncStream<Double> {
    AsyncStream { continuation in
        monitor.onProgress = { progress in
            continuation.yield(progress)
            if progress >= 1.0 {
                // I finish the stream at the callback boundary so consumers can use for-await cleanly.
                continuation.finish()
            }
        }

        continuation.onTermination = { _ in
            monitor.onProgress = nil
        }
    }
}

@main
struct DemoApp {
    static func main() async {
        let monitor = DownloadMonitor()

        Task {
            for await progress in progressStream(from: monitor) {
                print("Progress: \(Int(progress * 100))%")
            }
        }

        monitor.simulateDownload()
    }
}
