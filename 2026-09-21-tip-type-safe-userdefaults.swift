import Foundation

// I keep persistence details behind the wrapper so call sites stay honest about defaults.
@propertyWrapper
struct Default<Value: Codable> {
    private let key: String
    private let store: UserDefaults
    private let fallback: Value

    init(wrappedValue: Value, _ key: String, store: UserDefaults = .standard) {
        self.key = key
        self.store = store
        self.fallback = wrappedValue
    }

    var wrappedValue: Value {
        get {
            guard let data = store.data(forKey: key),
                  let value = try? JSONDecoder().decode(Value.self, from: data) else {
                return fallback
            }
            return value
        }
        nonmutating set {
            // Encoding makes arrays and structs work without per-type UserDefaults branches.
            let data = try? JSONEncoder().encode(newValue)
            store.set(data, forKey: key)
        }
    }
}

enum Settings {
    @Default("preferredTheme") static var preferredTheme = "system"
}

@main
enum Example {
    static func main() {
        Settings.preferredTheme = "dark"
        print(Settings.preferredTheme)
    }
}
