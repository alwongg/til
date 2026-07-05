# compactMap vs filter + map

I reach for `compactMap` when validation and transformation happen in the same step.

`filter` + `map` reads nicely when the predicate and the transform are genuinely separate. But if I’m just checking whether a transform succeeds, `compactMap` is the tighter tool: one pass, one closure, less drift between the “keep” rule and the “convert” rule.

```swift
import Foundation

struct UserID: RawRepresentable, Hashable {
    let rawValue: Int

    init?(rawValue: Int) {
        guard rawValue > 0 else { return nil }
        self.rawValue = rawValue
    }
}

enum UserIDParser {
    static func compactMapVersion(_ rawValues: [String]) -> [UserID] {
        rawValues.compactMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let intValue = Int(trimmed) else { return nil }
            return UserID(rawValue: intValue)
        }
    }

    static func filterThenMapVersion(_ rawValues: [String]) -> [UserID] {
        rawValues
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { Int($0) != nil }
            .compactMap { Int($0) }
            .compactMap(UserID.init(rawValue:))
    }
}

@main
struct Demo {
    static func main() {
        let payload = [" 42 ", "0", "abc", "19", "-7", "105"]
        let ids = UserIDParser.compactMapVersion(payload)
        print(ids.map(\.rawValue)) // [42, 19, 105]
    }
}
```

My rule of thumb: if the question is “can I turn this into the thing I want?”, `compactMap` is usually the cleanest expression.
