import Foundation

// I keep preference keys close to the value they represent so a typo cannot
// silently create a second, unused UserDefaults entry.
@propertyWrapper
struct UserDefault<Value: Codable> {
    let key: String
    let defaultValue: Value
    var store: UserDefaults = .standard

    var wrappedValue: Value {
        get {
            guard let data = store.data(forKey: key),
                  let value = try? JSONDecoder().decode(Value.self, from: data)
            else { return defaultValue }
            return value
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            store.set(data, forKey: key)
        }
    }
}

struct AppSettings {
    @UserDefault(key: "hasSeenOnboarding", defaultValue: false)
    var hasSeenOnboarding: Bool

    @UserDefault(key: "preferredCurrency", defaultValue: "CAD")
    var preferredCurrency: String
}

@main
struct Demo {
    static func main() {
        var settings = AppSettings()
        settings.hasSeenOnboarding = true
    }
}
