import Foundation

/*
# Tip: I default to safe subscripting when UI state can drift ahead of data

When I wire collection-backed UI, the crash usually isn't the interesting bug. It's the stale assumption that an index is still valid after async updates, filtering, or diffing.

This helper keeps the failure mode explicit: missing data becomes `nil`, and I decide what the UI should do next.
*/

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct Episode: CustomStringConvertible {
    let title: String
    var description: String { title }
}

struct QueueViewModel {
    private let episodes = [
        Episode(title: "Swift Concurrency"),
        Episode(title: "Observation in SwiftUI")
    ]

    func titleForRow(_ row: Int) -> String {
        episodes[safe: row]?.title ?? "Unavailable"
    }
}

@main
enum Demo {
    static func main() {
        let viewModel = QueueViewModel()
        print(viewModel.titleForRow(0))
        print(viewModel.titleForRow(3))
    }
}
