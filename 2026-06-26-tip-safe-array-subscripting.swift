import Foundation

// I use this when UI state and async data can race each other.
// Returning nil at the boundary is cheaper than letting an index trap crash the app.
extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct Episode: Identifiable {
    let id: UUID
    let title: String
}

enum QueuePresenter {
    static func nowPlayingTitle(from episodes: [Episode], selectedIndex: Int) -> String {
        guard let episode = episodes[safe: selectedIndex] else {
            return "Nothing queued"
        }
        return episode.title
    }
}

struct SafeSubscriptExamples {
    static func arrayUsage(_ episodes: [Episode]) -> Episode? {
        episodes[safe: 2]
    }

    static func stringUsage(_ text: String) -> Character? {
        let index = text.index(text.startIndex, offsetBy: 1, limitedBy: text.endIndex)
        guard let index else { return nil }
        return text[safe: index]
    }
}
