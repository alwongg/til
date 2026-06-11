/// 2026-06-11 Tip: Type-safe UserDefaults with @propertyWrapper
/// I like wrapping persisted flags so the call site stays declarative and key names stop leaking.

import Foundation

protocol UserDefaultsValue {}
extension Bool: UserDefaultsValue {}
extension Int: UserDefaultsValue {}
extension String: UserDefaultsValue {}

@propertyWrapper
struct Stored<Value: UserDefaultsValue> {
    let key: String
    let defaultValue: Value
    var store: UserDefaults = .standard

    var wrappedValue: Value {
        get { store.object(forKey: key) as? Value ?? defaultValue }
        set { store.set(newValue, forKey: key) }
    }
}

struct AppSettings {
    @Stored(key: "hasSeenOnboarding", defaultValue: false)
    var hasSeenOnboarding: Bool

    @Stored(key: "launchCount", defaultValue: 0)
    var launchCount: Int
}

@main
enum UserDefaultsTip {
    static func main() {
        var settings = AppSettings()

        // I keep persistence behind the wrapper so feature code reads like state, not storage plumbing.
        settings.hasSeenOnboarding = true
        settings.launchCount += 1

        print("hasSeenOnboarding:", settings.hasSeenOnboarding)
        print("launchCount:", settings.launchCount)
    }
}
