import Foundation

struct SessionCache {
    private(set) var storage: [String: Date] = [:]

    @discardableResult
    mutating func markSeen(_ screenID: String, at date: Date = .now) -> Bool {
        let isNewScreen = storage.updateValue(date, forKey: screenID) == nil
        return isNewScreen
    }
}

@main
enum DiscardableResultTip {
    static func main() {
        var cache = SessionCache()

        // I often call side-effect APIs for the mutation and only occasionally need the return value.
        cache.markSeen("home")

        // When I do care, the signal is still available without forcing `_ =` at every call site.
        let insertedProfile = cache.markSeen("profile")
        let touchedHomeAgain = cache.markSeen("home")

        print("profile inserted:", insertedProfile)
        print("home was new:", touchedHomeAgain)
        print("tracked screens:", cache.storage.keys.sorted())
    }
}
