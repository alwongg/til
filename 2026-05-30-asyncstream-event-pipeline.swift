import Foundation

/*:
 # When I Reach for AsyncStream Instead of NotificationCenter

 I still use `NotificationCenter` for framework-driven events, but for app-owned flows I reach for `AsyncStream` first.
 The win is simple: I keep events typed, I consume them with structured concurrency, and cancellation becomes part of the design instead of an afterthought.

 ## Legacy approach

 The old pattern is familiar: post a stringly-typed notification, unpack `userInfo`, then hope every observer remembers to remove itself.

 ```swift
 NotificationCenter.default.post(
     name: .uploadDidFinish,
     object: nil,
     userInfo: ["id": uploadID, "url": remoteURL]
 )
 ```

 That works, but it spreads event shape across multiple files:
 - the notification name
 - the `userInfo` keys
 - the casting logic in each observer
 - the lifecycle rules for observer cleanup

 ## Modern approach

 I prefer a tiny event hub backed by `AsyncStream`.
 Every consumer gets an `AsyncSequence`, so `for await` becomes the natural read path.

 ```swift
 struct UploadFinished: Sendable {
     let id: UUID
     let remoteURL: URL
 }

 actor UploadEvents {
     private var continuations: [UUID: AsyncStream<UploadFinished>.Continuation] = [:]

     func stream() -> AsyncStream<UploadFinished> {
         let token = UUID()

         return AsyncStream { continuation in
             continuations[token] = continuation

             continuation.onTermination = { [weak self] _ in
                 Task {
                     await self?.removeContinuation(for: token)
                 }
             }
         }
     }

     func publish(_ event: UploadFinished) {
         for continuation in continuations.values {
             continuation.yield(event)
         }
     }

     private func removeContinuation(for token: UUID) {
         continuations[token] = nil
     }
   }

 final class UploadCoordinator {
     private let events = UploadEvents()
     private var listenerTask: Task<Void, Never>?

     func startListening() {
         listenerTask = Task {
             let stream = await events.stream()
             for await event in stream {
                 print("Upload finished: \(event.id) -> \(event.remoteURL.absoluteString)")
             }
         }
     }

     func stopListening() {
         listenerTask?.cancel()
         listenerTask = nil
     }

     func simulateUploadCompletion() {
         Task {
             await events.publish(
                 UploadFinished(
                     id: UUID(),
                     remoteURL: URL(string: "https://example.com/file.jpg")!
                 )
             )
         }
     }
 }
 ```

 ## Migration strategy

 When I'm moving an existing feature over, I don't rewrite every observer at once.
 I usually do it in three passes:

 1. Define a typed event payload.
 2. Add an `AsyncStream` publisher beside the existing notification.
 3. Migrate consumers one by one until the notification path is dead code.

 That keeps the change incremental and makes it easy to prove I didn't break the event flow.

 ## Production notes

 - Use an `actor` around continuations so fan-out stays data-race safe.
 - Keep event payloads small and `Sendable`; pass identifiers, not giant mutable objects.
 - Cancellation is a feature: when a screen disappears, its task should die with it.
 - If I need replay, backpressure, or buffering semantics, I make that explicit instead of assuming broadcast behavior.

 `NotificationCenter` is still fine for system integration.
 For app-owned async workflows, `AsyncStream` gives me a shape that matches how modern Swift code already wants to run.
 */
