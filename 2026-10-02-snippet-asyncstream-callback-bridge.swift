# Bridge Delegate Callbacks to `AsyncStream`

I use `AsyncStream` to move delegate-style event sources into the same structured-concurrency world as the rest of an iOS feature. The stream owns continuation lifetime, and `onTermination` tears down the callback connection so a cancelled task does not keep work alive.

```swift
import Foundation

final class DownloadProgressBridge {
    private var continuation: AsyncStream<Double>.Continuation?

    func progressUpdates() -> AsyncStream<Double> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            self.continuation = continuation
            continuation.onTermination = { [weak self] _ in
                self?.continuation = nil
            }
        }
    }

    // Call this from a URLSession delegate or another callback boundary.
    func didReceiveProgress(_ progress: Double) {
        continuation?.yield(min(max(progress, 0), 1))
    }

    func didFinish() {
        continuation?.finish()
        continuation = nil
    }
}

@main
struct Demo {
    static func main() async {
        let bridge = DownloadProgressBridge()
        let updates = bridge.progressUpdates()

        let observer = Task {
            for await progress in updates {
                print("Progress: \(Int(progress * 100))%")
            }
        }

        bridge.didReceiveProgress(0.5)
        bridge.didFinish()
        _ = await observer.result
    }
}
```

`bufferingNewest(1)` is deliberate for UI progress: the screen needs the latest value, not every intermediate callback. I keep error and completion semantics explicit at the bridge boundary; for failable sources, I switch to `AsyncThrowingStream` rather than encoding failures as sentinel values.
