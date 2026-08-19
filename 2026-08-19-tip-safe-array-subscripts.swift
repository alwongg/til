// iOS Tip: Safe Array Subscripts
//
// I use an optional subscript at UI and parsing boundaries where an index can
// become stale between a snapshot and rendering. It makes the absence explicit
// instead of turning a recoverable state mismatch into a crash.

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct RecentSearches {
    private var terms = ["Swift", "SwiftUI", "Concurrency"]

    func title(forVisibleRow row: Int) -> String {
        // A list update can invalidate a previously captured row; the fallback
        // keeps this presentation concern local rather than leaking a trap.
        terms[safe: row] ?? "No recent search"
    }
}

// I still use normal subscripts when an invalid index is a programmer error.
// `safe` is for data that crosses an asynchronous or user-driven boundary.
