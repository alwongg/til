import Foundation

/*
 I use this pattern when I want UserDefaults convenience without stringly-typed keys.
 The real win is not fewer lines — it's making the read/write contract obvious at the call site.
 */
enum DefaultsKey<Value> {
    case hasSeenOnboarding
    case preferredTab

    var name: String {
        switch self {
        case .hasSeenOnboarding: return "has_seen_onboarding"
        case .preferredTab: return "preferred_tab"
        }
    }
}

@propertyWrapper
struct UserDefault<Value> {
    let key: DefaultsKey<Value>
    let defaultValue: Value
    var store: UserDefaults = .standard

    var wrappedValue: Value {
        get { store.object(forKey: key.name) as? Value ?? defaultValue }
        set { store.set(newValue, forKey: key.name) }
    }
}

struct AppSettings {
    @UserDefault(key: .hasSeenOnboarding, defaultValue: false) var hasSeenOnboarding: Bool
    @UserDefault(key: .preferredTab, defaultValue: "home") var preferredTab: String
}
