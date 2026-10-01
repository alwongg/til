// iOS Tip: Prefer compactMap when transformation can fail
//
// I reach for compactMap when parsing, lookup, or conversion can produce nil.
// It makes the intent explicit: transform valid values and discard invalid ones.
// filter + map splits that one invariant across two closures and can accidentally
// repeat work when the filtering condition needs the same conversion.

import Foundation

struct Endpoint: Hashable {
    let rawValue: String

    init?(_ rawValue: String) {
        guard let url = URL(string: rawValue), url.scheme != nil, url.host != nil else {
            return nil
        }
        self.rawValue = url.absoluteString
    }
}

func validatedEndpoints(from rawValues: [String]) -> [Endpoint] {
    rawValues.compactMap(Endpoint.init)
}

func parseIntegers(_ values: [String]) -> [Int] {
    values.compactMap(Int.init)
}

// `compactMap` keeps parsing exactly once per input. I use `filter` + `map`
// only when the filter is cheap, independent, and leaving the two operations
// separate tells a clearer business story.
func activeNames(from users: [(name: String, isActive: Bool)]) -> [String] {
    users
        .filter(\.isActive)
        .map(\.name)
}
