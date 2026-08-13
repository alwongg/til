// I use `defer` to make lifecycle cleanup survive every exit path.
//
// The useful rule is: acquire a resource, then register its cleanup immediately.
// That keeps early returns and thrown errors from quietly skipping teardown.

import Foundation

final class LoadingState {
    private(set) var isLoading = false

    func begin() { isLoading = true }
    func end() { isLoading = false }
}

enum ProfileError: Error { case invalidID }

func loadProfile(id: String, state: LoadingState) throws -> String {
    state.begin()
    defer { state.end() }

    guard !id.isEmpty else { throw ProfileError.invalidID }

    // `defer` runs for this successful path and for every throw/return above.
    return "Profile for \(id)"
}

@main
struct Demo {
    static func main() {
        let state = LoadingState()
        let profile = try? loadProfile(id: "42", state: state)
        print(profile ?? "Missing profile")
    }
}
