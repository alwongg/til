import Foundation

// I reach for safe indexing when UI state and async updates can drift out of sync.
// Returning nil makes boundary checks explicit at the call site instead of hiding crashes.
extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct Episode: CustomStringConvertible {
    let title: String
    var description: String { title }
}

let queue = [
    Episode(title: "Warm cache before first render"),
    Episode(title: "Cancel stale work on reuse"),
]

func renderNextEpisode(from episodes: [Episode], selectedIndex: Int) {
    guard let episode = episodes[safe: selectedIndex] else {
        print("Nothing to render for index \(selectedIndex)")
        return
    }

    // I prefer an early guard here because it keeps the success path linear.
    print("Rendering: \(episode)")
}

renderNextEpisode(from: queue, selectedIndex: 1)
renderNextEpisode(from: queue, selectedIndex: 3)
