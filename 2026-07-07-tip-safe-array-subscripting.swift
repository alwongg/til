import Foundation

// I like making invalid indexing boring instead of fatal.
// Optional access lets me keep call sites explicit without littering guards everywhere.
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
            Episode(title: "Parse once at the edge"),
            Episode(title: "Keep view models dumb"),
            Episode(title: "Prefer composition over hidden globals")
        ]

        print(queue[safe: 1] ?? Episode(title: "Missing"))
        print(queue[safe: 9] as Any)

        // The point isn't to hide bugs.
        // It's to use a non-crashing API in places where out-of-range is a valid state.
        if let nextUp = queue[safe: queue.index(after: queue.startIndex)] {
            print("Next up: \(nextUp)")
        }
    }
}
