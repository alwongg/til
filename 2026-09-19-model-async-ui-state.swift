// 2026-09-19 — Quick Concept: Model async UI as a state machine
//
// I avoid Boolean combinations like `isLoading`, `hasError`, and `data`.
// They permit impossible states: loading and failed at once, or content with
// a stale error. One enum makes each screen state explicit and switchable.

import Foundation

enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(message: String)
}

struct Profile: Equatable {
    let name: String
}

func screenText(for state: LoadState<Profile>) -> String {
    switch state {
    case .idle:
        return "Pull to refresh"
    case .loading:
        return "Loading profile…"
    case .loaded(let profile):
        return "Welcome, \(profile.name)"
    case .failed(let message):
        return "Couldn’t load profile: \(message)"
    }
}

@main
struct Demo {
    static func main() {
        let state: LoadState<Profile> = .loaded(Profile(name: "Alex"))
        print(screenText(for: state))
    }
}

// Migration strategy: start at the ViewModel boundary. Replace related flags
// with one `LoadState`, then let compiler-exhaustive switches reveal every UI
// branch that needs updating. In production I keep retry intent as an action,
// not another state flag, so state remains a snapshot instead of a command log.
