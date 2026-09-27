// iOS Tip — Safe Array Subscripts
//
// I use a safe subscript at UI boundaries: table selections, deep links, and
// server-driven indexes. It makes an invalid index explicit as `nil` instead
// of turning a recoverable state mismatch into a crash.
//
// The important choice is not to use this in my core algorithms. A normal
// subscript still documents an invariant that must hold. This version is for
// values crossing an unreliable boundary.

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct FeedItem: Equatable {
    let id: Int
    let title: String
}

@main
struct SafeSubscriptDemo {
    static func main() {
        let items = [
            FeedItem(id: 1, title: "Inbox"),
            FeedItem(id: 2, title: "Saved")
        ]

        let restoredSelection = 3 // A persisted UI index can be stale.
        guard let item = items[safe: restoredSelection] else {
            return // I show an empty state or clear the stale selection here.
        }

        print(item.title)
    }
}
