import Foundation

// I use this at UI and decoding boundaries where an invalid index is expected
// occasionally, but crashing would turn recoverable stale state into a defect.
extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct RecentSearches {
    private var items = ["swift", "swiftui", "concurrency"]

    func displayTitle(for selectedIndex: Int?) -> String {
        guard let selectedIndex,
              let query = items[safe: selectedIndex] else {
            return "No recent search"
        }
        return "Search: \(query)"
    }
}

func demonstrateSafeLookup() {
    let searches = RecentSearches()
    _ = searches.displayTitle(for: 1)   // Search: swiftui
    _ = searches.displayTitle(for: 99)  // No recent search
}
