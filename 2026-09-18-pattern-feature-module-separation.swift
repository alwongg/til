# Feature Modules: Keep the Dependency Direction Boring

When a feature grows, I stop treating its SwiftUI screen as the unit of design. I treat the feature as a small vertical slice with one dependency direction:

`Model → Repository → UseCase → ViewModel → View`

The useful part is not the folder names. It is that the view model depends on an intent-focused use case, while infrastructure stays behind a protocol.

```swift
import Foundation

struct Profile: Sendable, Equatable {
    let id: UUID
    let name: String
}

protocol ProfileRepository: Sendable {
    func profile(id: UUID) async throws -> Profile
}

struct LoadProfile {
    let repository: any ProfileRepository

    func callAsFunction(id: UUID) async throws -> Profile {
        try await repository.profile(id: id)
    }
}

@MainActor
final class ProfileViewModel {
    private let loadProfile: LoadProfile
    private(set) var name = ""

    init(loadProfile: LoadProfile) {
        self.loadProfile = loadProfile
    }

    func refresh(id: UUID) async {
        do { name = try await loadProfile(id: id).name }
        catch { name = "Unavailable" }
    }
}
```

## Why I use this boundary

- **Tests stay cheap.** I can give `LoadProfile` a fake repository without rendering SwiftUI or configuring networking.
- **Views remain replaceable.** A widget, a UIKit screen, and a SwiftUI view can share the same use case.
- **Policy gets a home.** Caching, authorization, retries, and mapping belong in the use case or repository—not in button actions.

## Migration strategy

I start by extracting one read path behind a repository protocol. Next I introduce a small use case only where business rules or orchestration appear. I do not create a use case for every property access; that turns the boundary into ceremony.

## Production note

Keep repository implementations in the data layer and inject them at the composition root. Avoid importing networking or persistence modules into view models. The compiler then enforces the direction that code review usually misses.
