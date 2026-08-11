// iOS Tip: Choose compactMap when transformation can fail
//
// I use `compactMap` when decoding or parsing can produce nil. It keeps the
// pipeline honest: transform each value, then discard only failed transforms.
// `filter + map` is clearer when the predicate and transform are genuinely
// separate operations.

import Foundation

struct DeepLink: Equatable {
    let path: String

    init?(rawValue: String) {
        guard rawValue.hasPrefix("myapp://") else { return nil }
        path = String(rawValue.dropFirst("myapp://".count))
    }
}

func validDeepLinks(from rawValues: [String]) -> [DeepLink] {
    rawValues.compactMap(DeepLink.init(rawValue:))
}

func visibleNames(from names: [String?]) -> [String] {
    // Here filtering a business rule before mapping is easier to scan.
    names
        .filter { ($0?.isEmpty == false) }
        .map { $0! }
}

func example() {
    let links = validDeepLinks(from: ["myapp://inbox", "https://example.com"])
    precondition(links == [DeepLink(rawValue: "myapp://inbox")!])

    let names = visibleNames(from: ["Alex", nil, ""])
    precondition(names == ["Alex"])
}
