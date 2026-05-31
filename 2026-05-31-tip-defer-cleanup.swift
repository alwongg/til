import Foundation

func loadProfile() throws -> String {
    let requestID = UUID()
    let startedAt = Date()

    print("Starting request \(requestID.uuidString)")

    // I use defer when setup and cleanup belong to the same story.
    // It keeps teardown from drifting into every early return path.
    defer {
        let elapsed = Date().timeIntervalSince(startedAt)
        print("Finished request \(requestID.uuidString) in \(elapsed)s")
    }

    let cacheHit = Bool.random()
    if cacheHit {
        return "cached-profile"
    }

    let responseStatus = 200
    guard responseStatus == 200 else {
        struct RequestError: Error {}
        throw RequestError()
    }

    return "remote-profile"
}

do {
    let profile = try loadProfile()
    print("Loaded: \(profile)")
} catch {
    print("Request failed: \(error)")
}

// My rule of thumb: if a function opens work that must always be closed,
// defer keeps the cleanup honest when the body grows over time.
