import Foundation

extension Collection {
    /// I use this when indexing comes from UI state or remote data.
    /// Returning nil keeps boundary code honest instead of crashing in production.
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

let sections = ["Inbox", "Today", "Done"]

let currentTab = 3
let visibleTitle = sections[safe: currentTab] ?? "Fallback"
print(visibleTitle)

struct Pager<State> {
    var items: [State]

    mutating func advance(from index: Int) -> State? {
        let next = index + 1
        // I prefer optional flow here because pagination drift is normal,
        // especially when server updates race with local mutations.
        return items[safe: next]
    }
}

var pager = Pager(items: [1, 2, 3])
print(pager.advance(from: 1) as Any)
print(pager.advance(from: 9) as Any)
