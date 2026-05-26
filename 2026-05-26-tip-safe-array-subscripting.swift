import Foundation

// 2026-05-26 — iOS Tip
// Title: Safe array subscripting
//
// I reach for a safe subscript whenever an index comes from UI state or async data.
// It keeps the happy path readable and turns out-of-bounds access into an explicit nil.

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct Episode {
    let title: String
}

let queue = [
    Episode(title: "Intro"),
    Episode(title: "Concurrency"),
    Episode(title: "Persistence"),
]

func playEpisode(at index: Int) {
    guard let episode = queue[safe: index] else {
        // I prefer logging or fallback UI here instead of crashing on a stale index.
        print("No episode at index \(index)")
        return
    }

    print("Playing: \(episode.title)")
}

playEpisode(at: 1)
playEpisode(at: 9)
