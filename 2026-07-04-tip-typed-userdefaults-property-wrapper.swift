import Foundation

@propertyWrapper
struct UserDefault<Value> {
    let key: String
    let defaultValue: Value
    var storage: UserDefaults = .standard

    var wrappedValue: Value {
        get { storage.object(forKey: key) as? Value ?? defaultValue }
        set { storage.set(newValue, forKey: key) }
    }
}

enum Preferences {
    @UserDefault(key: "hasSeenOnboarding", defaultValue: false)
    static var hasSeenOnboarding: Bool

    @UserDefault(key: "launchCount", defaultValue: 0)
    static var launchCount: Int

    @UserDefault(key: "preferredTab", defaultValue: "home")
    static var preferredTab: String
}

@main
struct Demo {
    static func main() {
        Preferences.launchCount += 1
        Preferences.hasSeenOnboarding = true
        print(Preferences.launchCount)
    }
}
