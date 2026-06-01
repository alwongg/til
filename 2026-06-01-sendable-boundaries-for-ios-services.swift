import Foundation

/*:
 # How I Move iOS Services Toward Sendable Boundaries

 One of the biggest Swift shifts I’ve felt in production isn’t syntax. It’s the move from “this probably won’t race” to code that makes concurrency boundaries explicit.

 Older iOS services often work because the app is lucky: a mutable class is shared everywhere, callbacks hop across queues, and state changes depend on unwritten threading assumptions.
 Swift’s `Sendable` model plus actors gives me a cleaner rule: if data crosses concurrency domains, I want that boundary to be obvious in the type system.

 ## Legacy approach

 This is the kind of service shape I still find in older codebases:

 ```swift
 final class LegacySessionCache {
     private var tokens: [String: String] = [:]

     func token(for userID: String, completion: @escaping (String?) -> Void) {
         DispatchQueue.global().async {
             let value = self.tokens[userID]
             completion(value)
         }
     }

     func store(token: String, for userID: String) {
         tokens[userID] = token
     }
 }
 ```

 The issue isn’t that this code looks dramatic. The issue is that ownership is vague:
 - `tokens` is mutable shared state
 - reads and writes happen from different execution contexts
 - the completion handler doesn’t say anything about thread safety
 - every new caller has to remember the unwritten rules

 ## Modern approach

 I prefer to make the boundary explicit with an actor and `Sendable` models.

 ```swift
 struct SessionToken: Sendable, Equatable {
     let userID: String
     let value: String
     let expiresAt: Date

     var isExpired: Bool {
         expiresAt <= Date()
     }
 }

 protocol SessionTokenStore: Sendable {
     func token(for userID: String) async -> SessionToken?
     func store(_ token: SessionToken) async
     func removeToken(for userID: String) async
 }

 actor InMemorySessionTokenStore: SessionTokenStore {
     private var tokens: [String: SessionToken] = [:]

     func token(for userID: String) async -> SessionToken? {
         guard let token = tokens[userID], !token.isExpired else {
             tokens[userID] = nil
             return nil
         }

         return token
     }

     func store(_ token: SessionToken) async {
         tokens[token.userID] = token
     }

     func removeToken(for userID: String) async {
         tokens[userID] = nil
     }
 }

 struct SessionService: Sendable {
     private let store: any SessionTokenStore

     init(store: any SessionTokenStore) {
         self.store = store
     }

     func cachedAuthorizationHeader(for userID: String) async -> String? {
         guard let token = await store.token(for: userID) else {
             return nil
         }

         return "Bearer \(token.value)"
     }
 }

 @main
 enum Demo {
     static func main() async {
         let store = InMemorySessionTokenStore()
         let service = SessionService(store: store)

         await store.store(
             SessionToken(
                 userID: "42",
                 value: "abc123",
                 expiresAt: Date().addingTimeInterval(300)
             )
         )

         let header = await service.cachedAuthorizationHeader(for: "42")
         print(header ?? "Missing token")
     }
 }
 ```

 The practical win is that Swift now helps me defend the boundary:
 - the token model is safe to move across tasks
 - the actor owns mutation
 - callers consume async APIs instead of queue conventions
 - dependencies advertise concurrency expectations up front

 ## Migration strategy

 I usually move an existing feature in four passes:

 1. Identify one shared mutable type that crosses task or queue boundaries.
 2. Convert the payload models to `Sendable` first, because that surfaces unsafe references early.
 3. Wrap the mutable state inside an actor before rewriting higher-level flows.
 4. Replace callback-based reads with async entry points at the feature edge, not everywhere at once.

 That sequence keeps the change incremental. I can lock down one boundary without pausing the rest of the app.

 ## Production notes

 - `Sendable` is most valuable when I treat warnings as architectural feedback, not compiler noise.
 - If I have a reference type that truly must cross concurrency domains, I make that decision explicit with careful isolation instead of pretending it’s harmless.
 - Actors protect mutation, but they don’t automatically fix bad ownership. I still want small state and clear responsibilities.
 - I avoid sprinkling `@unchecked Sendable` around just to make warnings disappear. That usually means I’m hiding risk instead of removing it.

 Swift’s concurrency evolution pushed me toward code that is a little stricter but a lot easier to trust. In production, that trade is worth it.
 */
