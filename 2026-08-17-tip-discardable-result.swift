// I use @discardableResult when an operation has a useful value for callers
// that care, without forcing every call site to bind it.

import Foundation

struct Cache<Key: Hashable, Value> {
    private var storage: [Key: Value] = [:]

    @discardableResult
    mutating func insert(_ value: Value, for key: Key) -> Value? {
        // Returning the replaced value makes cache invalidation observable,
        // while ordinary writes remain uncluttered.
        storage.updateValue(value, forKey: key)
    }

    @discardableResult
    mutating func removeValue(for key: Key) -> Value? {
        storage.removeValue(forKey: key)
    }

    func value(for key: Key) -> Value? {
        storage[key]
    }
}

@main
struct Demo {
    static func main() {
        var cache = Cache<String, Int>()
        cache.insert(1, for: "launchCount")

        let previous = cache.insert(2, for: "launchCount")
        assert(previous == 1)
    }
}
