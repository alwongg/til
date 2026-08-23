// I use `defer` to make cleanup structural rather than relying on every
// early-return path remembering it. The cleanup is registered immediately
// after acquisition, so future edits cannot accidentally skip it.
import Foundation

final class LoadingGate {
    private(set) var isLoading = false

    func begin() { isLoading = true }
    func end() { isLoading = false }
}

enum ProfileError: Error { case unavailable }

func refreshProfile(
    gate: LoadingGate,
    load: () throws -> String
) throws -> String {
    gate.begin()
    defer { gate.end() }

    let profile = try load()
    guard !profile.isEmpty else { throw ProfileError.unavailable }
    return profile
}

@main
struct Demo {
    static func main() {
        let gate = LoadingGate()
        let name = try? refreshProfile(gate: gate) { "Alex" }
        print(name ?? "No profile", gate.isLoading) // Alex false
    }
}
