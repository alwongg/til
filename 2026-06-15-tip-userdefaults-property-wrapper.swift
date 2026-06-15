import Foundation

protocol UserDefaultsStorable {
    static func read(from defaults: UserDefaults, key: String) -> Self?
    func write(to defaults: UserDefaults, key: String)
}

extension String: UserDefaultsStorable {
    static func read(from defaults: UserDefaults, key: String) -> String? { defaults.string(forKey: key) }
    func write(to defaults: UserDefaults, key: String) { defaults.set(self, forKey: key) }
}

extension Bool: UserDefaultsStorable {
    static func read(from defaults: UserDefaults, key: String) -> Bool? {
        defaults.object(forKey: key) as? Bool
    }

    func write(to defaults: UserDefaults, key: String) {
        defaults.set(self, forKey: key)
    }
}

@propertyWrapper
struct UserDefault<Value: UserDefaultsStorable> {
    let key: String
    let defaultValue: Value
    var defaults: UserDefaults = .standard

    var wrappedValue: Value {
        get {
            Value.read(from: defaults, key: key) ?? defaultValue
        }
        set {
            newValue.write(to: defaults, key: key)
        }
    }
}

struct AppSettings {
    @UserDefault(key: "has_seen_onboarding", defaultValue: false)
    var hasSeenOnboarding: Bool

    @UserDefault(key: "preferred_tab", defaultValue: "home")
    var preferredTab: String
}
