import Foundation

struct Build {
    let scheme: String
    let lane: String
}

let builds = [
    Build(scheme: "Checkout", lane: "release"),
    Build(scheme: "Feed", lane: "debug"),
    Build(scheme: "Checkout", lane: "debug"),
    Build(scheme: "Profile", lane: "release")
]

let groupedByScheme = Dictionary(grouping: builds, by: \.scheme)

for scheme in groupedByScheme.keys.sorted() {
    let lanes = groupedByScheme[scheme, default: []].map(\.lane).sorted()
    print("\(scheme): \(lanes)")
}

let countsByScheme = groupedByScheme.mapValues(\.count)
print(countsByScheme) // ["Checkout": 2, "Feed": 1, "Profile": 1]

// I use this when I need quick sectioning without inventing a manual accumulator.
// The win is clarity: the grouping rule stays at the call site instead of being hidden in mutation.
// If I care about order for UI sections, I pair the grouped dictionary with a separately sorted key list.
