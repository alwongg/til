# Quick Concept — Cancellation-first workflows in Swift Concurrency

I treat cancellation as part of the happy path now, not as an error case I remember to clean up later.

## Legacy approach
A lot of older async code assumes work should run until it finishes:
- kick off a task
- ignore cancellation until the end
- hope `defer` or object deinit cleans everything up

That usually leaves me with stale UI updates, wasted network work, and cleanup that happens too late.

## Modern approach
In Swift Concurrency, I want cancellation checks close to the expensive boundary:
- before starting work
- after suspension points
- before committing results back to state

When cleanup must happen immediately, I wrap the operation in `withTaskCancellationHandler` so cancellation has a real code path.

```swift
import Foundation

actor ImageCache {
    private var storage: [URL: Data] = [:]

    func insert(_ data: Data, for url: URL) {
        storage[url] = data
    }

    func removeValue(for url: URL) {
        storage.removeValue(forKey: url)
    }
}

struct ImagePipeline {
    let cache: ImageCache

    func loadImageData(from url: URL) async throws -> Data {
        try Task.checkCancellation()

        return try await withTaskCancellationHandler(operation: {
            let data = try await simulateNetworkLoad(from: url)
            try Task.checkCancellation()
            await cache.insert(data, for: url)
            return data
        }, onCancel: {
            Task {
                await cache.removeValue(for: url)
            }
        })
    }

    private func simulateNetworkLoad(from url: URL) async throws -> Data {
        try await Task.sleep(for: .milliseconds(250))
        return Data(url.absoluteString.utf8)
    }
}
```

## Migration strategy
When I refactor older completion-handler code, I usually do it in this order:
1. move the async boundary into one focused function
2. add `Task.checkCancellation()` before and after the expensive suspend point
3. add a cancellation handler only if I truly own cleanup work
4. guard the final state write so cancelled work never wins the race back to the UI

## Production notes
- Cancellation is cooperative. If I never check for it, Swift won't magically stop my work in the right place.
- `onCancel` should be fast and predictable. I use it for cleanup, not for starting a second workflow.
- I avoid updating view model state after a cancelled task, even if the request technically finished.
- If cancellation is common, I design APIs so cleanup is idempotent.

The mental model that helped me most: cancellation is not failure. It's a signal that the result is no longer worth delivering.
