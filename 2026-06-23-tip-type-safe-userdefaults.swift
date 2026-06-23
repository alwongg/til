import Foundation

// 2026-06-23 · Tip · type-safe UserDefaults with @propertyWrapper
// I stop stringly-typed defaults from leaking across the app by putting the key,
// default value, and storage policy behind a small property wrapper.

protocol UserDefaultsKey {
    associatedtype Value
    static var name: String { get }
    static var defaultValue: Value { get }
}

@propertyWrapper
struct UserDefaultBacked<Key: UserDefaultsKey> {
    private let store: UserDefaults

    init(store: UserDefaults = .standard) {
        self.store = store
    }

    var wrappedValue: Key.Value {
        get {
            store.object(forKey: Key.name) as? Key.Value ?? Key.defaultValue
        }
        set {
            store.set(newValue, forKey: Key.name)
        }
    }
}

enum HasSeenOnboardingKey: UserDefaultsKey {
    static let name = "has_seen_onboarding"
    static let defaultValue = false
    typealias Value = Bool
}

enum PreferredTabKey: UserDefaultsKey {
    static let name = "preferred_tab"
    static let defaultValue = "home"
    typealias Value = String
}

struct AppPreferences {
    @UserDefaultBacked<HasSeenOnboardingKey> var hasSeenOnboarding
    @UserDefaultBacked<PreferredTabKey> var preferredTab
}
