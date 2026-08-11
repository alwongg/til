# Lightweight DI Container for Feature Assembly

When a feature has more than one dependency, I stop constructing everything inside the view model. A tiny container keeps composition at the app boundary while preserving explicit constructor injection.

```swift
import Foundation

protocol ProfileLoading {
    func loadProfile(id: UUID) async throws -> String
}

struct ProfileRepository: ProfileLoading {
    func loadProfile(id: UUID) async throws -> String { "Alex" }
}

@MainActor
final class ProfileViewModel {
    private let loader: ProfileLoading
    private let userID: UUID

    init(loader: ProfileLoading, userID: UUID) {
        self.loader = loader
        self.userID = userID
    }

    func refresh() async throws -> String {
        try await loader.loadProfile(id: userID)
    }
}

struct AppContainer {
    let profileLoader: ProfileLoading

    init(profileLoader: ProfileLoading = ProfileRepository()) {
        self.profileLoader = profileLoader
    }

    @MainActor
    func makeProfileViewModel(userID: UUID) -> ProfileViewModel {
        ProfileViewModel(loader: profileLoader, userID: userID)
    }
}

@main
struct Demo {
    static func main() async {
        let container = AppContainer()
        let model = container.makeProfileViewModel(userID: UUID())
        print(try! await model.refresh())
    }
}
```

## Why I use this

- The view model declares what it needs; it never reaches for a global singleton.
- Tests can inject a deterministic `ProfileLoading` fake without booting the app graph.
- The container is intentionally boring: it owns construction, not service-location APIs scattered through features.

## Production note

I keep containers scoped to an app or feature boundary. For stateful services such as authenticated sessions, I make lifetime explicit in the container rather than hiding it behind `static shared`.
