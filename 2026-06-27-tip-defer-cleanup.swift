import Foundation

// Tip: I use `defer` when state cleanup must happen on every exit path.
// The common iOS version is a loading flag that should flip back to false
// whether the request succeeds, throws, or returns early from validation.

@MainActor
final class ProfileViewModel {
    private(set) var isLoading = false
    private(set) var message = ""

    func refreshProfile(id: String) async {
        guard !id.isEmpty else {
            message = "Missing id"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let profile = try await loadProfile(id: id)
            message = "Loaded \(profile.name)"
        } catch {
            message = "Retry later: \(error.localizedDescription)"
        }
    }

    private func loadProfile(id: String) async throws -> Profile {
        // In production this is usually URLSession + decoding.
        try await Task.sleep(nanoseconds: 50_000_000)
        return Profile(name: "Alex")
    }
}

struct Profile {
    let name: String
}

// Why I like this:
// - I set the cleanup rule once, beside the state change that starts it.
// - New early returns or throws do not create hidden UI bugs.
// - The function stays readable because cleanup is not duplicated in every branch.
