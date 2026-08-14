# iOS Tip: Safe Array Subscripting Without Hiding Missing-State Bugs

I use a safe subscript at UI boundaries, where stale indices are normal: a collection-view snapshot can change between an event and a lookup, or a selected index can outlive a filtered list. It makes that boundary explicit without turning every call site into range-check boilerplate.

```swift
import Foundation

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct FeedItem: Equatable {
    let id: UUID
    let title: String
}

func titleForSelection(
    selectedIndex: Int?,
    items: [FeedItem]
) -> String {
    guard let selectedIndex, let item = items[safe: selectedIndex] else {
        return "Nothing selected"
    }

    return item.title
}
```

The important part is the return type: `Element?` forces the caller to decide what an unavailable element means. I prefer this for presentation and event handling, but not for invariants inside my domain logic. If an index must exist after a validated transformation, a normal subscript should still fail loudly—it catches a broken assumption rather than quietly masking it.

I also keep the extension constrained to `Collection`, not just `Array`, so the same intent works with slices and other collection types. The method uses `indices.contains(index)` rather than integer comparisons, because a collection index is not guaranteed to be an `Int` or to start at zero.
