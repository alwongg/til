import Foundation

// I use a safe subscript when the index comes from UI state, remote data,
// or anything else that can drift underneath me. Returning nil makes the
// failure explicit and keeps the call site honest.
extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct Episode {
    let title: String
}

@main
struct SafeArraySubscriptTip {
    static func main() {
        let queue = [
            Episode(title: "Intro to Swift Concurrency"),
            Episode(title: "NavigationStack Deep Dive")
        ]

        let highlighted = queue[safe: 1]?.title ?? "Nothing highlighted"
        print(highlighted)

        let fallback = queue[safe: 5]?.title ?? "No crash, just nil"
        print(fallback)
    }
}
