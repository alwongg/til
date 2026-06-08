// type-safe UserDefaults with @propertyWrapper
//
// I use this when I want settings access to stay strongly typed and easy to audit.

import Foundation

protocol UserDefaultsCompatible {
    static func readValue(from defaults: UserDefaults, key: String) -> Self?
    func writeValue(to defaults: UserDefaults, key: String)
}

extension Bool: UserDefaultsCompatible {
    static func readValue(from defaults: UserDefaults, key: String) -> Bool? { defaults.object(forKey: key) as? Bool }
    func writeValue(to defaults: UserDefaults, key: String) { defaults.set(self, forKey: key) }
}

@propertyWrapper
struct Stored<Value: UserDefaultsCompatible> {
    let key: String
    let defaultValue: Value
    var defaults: UserDefaults = .standard

    var wrappedValue: Value {
        get { Value.readValue(from: defaults, key: key) ?? defaultValue }
        set { newValue.writeValue(to: defaults, key: key) }
    }
}

struct PlayerSettings {
    @Stored(key: "shouldAutoplay", defaultValue: false) var shouldAutoplay: Bool
}

var settings = PlayerSettings()
print(settings.shouldAutoplay)
settings.shouldAutoplay = true
print(settings.shouldAutoplay)
