# iOS Tip: Safe Array Subscripts

I use a safe subscript at UI boundaries where data can change between the time I compute an index and the time I render it. It keeps a stale index from becoming a crash while making the optionality explicit at the call site.

```swift
import Foundation

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct RowViewModel {
    let title: String
}

struct ScreenState {
    private(set) var rows: [RowViewModel]

    func row(at index: Int) -> RowViewModel? {
        // A diffable update can invalidate an index after it was selected.
        rows[safe: index]
    }
}

@main
struct SafeSubscriptDemo {
    static func main() {
        let state = ScreenState(rows: [.init(title: "Inbox")])
        let title = state.row(at: 1)?.title ?? "Unavailable"
        print(title)
    }
}
```

I do not use this to hide a logic error in core business code; assertions and correct invariants belong there. I use it at asynchronous UI and collection boundaries, then choose a deliberate fallback: ignore a stale selection, reload state, or show an empty view.