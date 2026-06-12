import Foundation

/*
 # From Duplicate Network Work to Request Coalescing in Production iOS

 One of the easiest ways to waste battery, bandwidth, and backend headroom in an iOS app is to let identical requests race each other.

 It usually starts innocently: one screen asks for an avatar, a prefetch path asks for the same avatar, and a newly mounted cell asks again before the first response lands. The app still "works," but now the system is doing duplicate work at the exact moment the UI is under load.

 When I want a feature to scale cleanly, I stop thinking only about caching and start thinking about coalescing. A cache helps after the first request finishes. Coalescing helps while the request is still in flight.

 ## Legacy approach

 This is the shape I try to retire:

 ```swift
 final class AvatarStore {
     private let api = AvatarAPIClient.shared
     private var cache: [String: Data] = [:]

     func avatar(for userID: String) async throws -> Data {
         if let cached = cache[userID] {
             return cached
         }

         let data = try await api.fetchAvatar(userID: userID)
         cache[userID] = data
         return data
     }
 }
 ```

 The bug is subtle: if three callers ask for the same avatar before `fetchAvatar` returns, all three requests go over the network.

 In production that compounds fast:
 - scrolling spikes duplicate fetches
 - retry logic multiplies the waste
 - background prefetching competes with visible UI work
 - analytics show "traffic growth" that is really coordination failure

 ## Modern approach

 I prefer an actor-backed repository that owns both the cache and the in-flight task table.
 */

protocol AvatarFetching: Sendable {
    func fetchAvatar(userID: UserID) async throws -> Data
}

struct UserID: Hashable, Sendable, CustomStringConvertible {
    let rawValue: String

    var description: String { rawValue }
}

enum AvatarError: Error {
    case missingData
}

actor MockAvatarAPI: AvatarFetching {
    private(set) var fetchCount: Int = 0

    func fetchAvatar(userID: UserID) async throws -> Data {
        fetchCount += 1
        try await Task.sleep(for: .milliseconds(120))

        guard let data = "avatar-\(userID.rawValue)".data(using: .utf8) else {
            throw AvatarError.missingData
        }

        return data
    }

    func observedFetchCount() -> Int {
        fetchCount
    }
}

actor AvatarRepository {
    private let api: any AvatarFetching
    private var cache: [UserID: Data] = [:]
    private var inFlight: [UserID: Task<Data, Error>] = [:]

    init(api: any AvatarFetching) {
        self.api = api
    }

    func avatar(for userID: UserID) async throws -> Data {
        if let cached = cache[userID] {
            return cached
        }

        if let existingTask = inFlight[userID] {
            // Coalescing matters before a cache hit exists.
            return try await existingTask.value
        }

        let task = Task<Data, Error> {
            try await api.fetchAvatar(userID: userID)
        }

        inFlight[userID] = task

        do {
            let data = try await task.value
            cache[userID] = data
            inFlight[userID] = nil
            return data
        } catch {
            // Failed work should not poison future callers.
            inFlight[userID] = nil
            throw error
        }
    }

    func cachedUserCount() -> Int {
        cache.count
    }
}

struct AvatarViewModel: Sendable {
    let repository: AvatarRepository

    func loadVisibleAvatars(for userIDs: [UserID]) async throws -> [String] {
        try await withThrowingTaskGroup(of: String.self) { group in
            for userID in userIDs {
                group.addTask {
                    let data = try await repository.avatar(for: userID)
                    return String(decoding: data, as: UTF8.self)
                }
            }

            var results: [String] = []
            for try await value in group {
                results.append(value)
            }
            return results.sorted()
        }
    }
}

@main
struct Demo {
    static func main() async {
        let api = MockAvatarAPI()
        let repository = AvatarRepository(api: api)
        let viewModel = AvatarViewModel(repository: repository)

        let repeatedIDs = [
            UserID(rawValue: "42"),
            UserID(rawValue: "42"),
            UserID(rawValue: "42"),
            UserID(rawValue: "7")
        ]

        do {
            let avatars = try await viewModel.loadVisibleAvatars(for: repeatedIDs)
            let fetchCount = await api.observedFetchCount()
            let cacheCount = await repository.cachedUserCount()

            print("avatars=\(avatars)")
            print("network_fetches=\(fetchCount)")
            print("cached_users=\(cacheCount)")
        } catch {
            print("load_failed=\(error)")
        }
    }
}

/*
 What I like about this shape:
 - the repository becomes the single concurrency boundary for this resource
 - duplicate visible work naturally folds into one request per identity
 - the UI can stay simple because the coordination cost moved downward
 - retries, cancellation, and metrics now have one place to live

 ## Migration strategy

 I usually move toward this in four passes:

 1. Put the existing fetch path behind a small protocol instead of calling the client directly from views or view models.
 2. Introduce a repository that owns the cache first, even if it still duplicates in-flight work.
 3. Add an in-flight task map keyed by request identity so concurrent demand collapses into one request.
 4. Instrument coalesced hits, total fetches, and failure rates before expanding the pattern across more endpoints.

 ## Production notes

 - I key coalescing by the true request identity, not just a user ID, once size, format, auth scope, or locale can change the payload.
 - I treat actors as the coordination primitive and keep the API client dumb; that separation makes testing easier.
 - Coalescing is not a replacement for caching. I want both because they solve different timing windows.
 - If memory pressure matters, I swap the dictionary cache for an eviction policy without changing the call site contract.
 */
