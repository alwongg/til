import Foundation

// Safe array subscripting
// I use this when async data and UI selection can drift for a frame.
// Returning nil keeps the failure at the boundary instead of crashing in production.

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct Episode: CustomStringConvertible {
    let title: String
    var description: String { title }
}

@main
enum Demo {
    static func main() {
        let queue = [
            Episode(title: "Intro"),
            Episode(title: "Diffable Data Source")
        ]

        print(queue[safe: 0] ?? Episode(title: "Missing"))
        print(queue[safe: 2]?.title ?? "No episode at index 2")
    }
}
