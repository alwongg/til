// safe array subscripting
//
// I use this when I want call sites to stay clean without sprinkling index guards everywhere.

import Foundation

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

let guests = ["Alex", "Mochi", "Host"]

print(guests[safe: 0] ?? "missing")
print(guests[safe: 2] ?? "missing")
print(guests[safe: 3] ?? "missing")

struct EpisodeQueue {
    private let titles: [String]

    init(titles: [String]) {
        self.titles = titles
    }

    func next(after currentIndex: Int) -> String? {
        // Returning nil makes end-of-list a normal control-flow case instead of a crash path.
        titles[safe: currentIndex + 1]
    }
}

let queue = EpisodeQueue(titles: ["Intro", "Networking", "Performance"])
print(queue.next(after: 1) ?? "done")
print(queue.next(after: 2) ?? "done")
