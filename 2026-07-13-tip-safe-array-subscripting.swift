// Safe Array Subscripting
//
// I still like optional-returning access better than sprinkling bounds checks
// through view models and collection transforms. The call site stays honest:
// if the index can be wrong, the type forces me to deal with it.

import Foundation

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct Episode: Equatable {
    let title: String
}

struct QueueViewState {
    let episodes: [Episode]

    func currentTitle(at index: Int) -> String {
        episodes[safe: index]?.title ?? "Up next"
    }

    func removingEpisode(at index: Int) -> [Episode] {
        guard episodes[safe: index] != nil else { return episodes }
        var copy = episodes
        copy.remove(at: index)
        return copy
    }
}

// Why I use it in production:
// - UI state often races user interaction during async refreshes.
// - Returning nil is safer than trapping for non-critical reads.
// - The helper keeps the fallback decision at the call site instead of hiding it.
