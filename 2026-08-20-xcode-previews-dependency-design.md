# Xcode Previews as a Dependency-Design Test

I used to treat Xcode Previews as a final UI check: get the screen building, wire it to the app container, then hope a preview can survive the production dependency graph. That made previews slow and fragile—and it hid a design problem: my views knew too much about infrastructure.

## Legacy approach

```swift
struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel(
        service: LiveProfileService(),
        analytics: FirebaseAnalytics()
    )

    var body: some View {
        ProfileContent(state: viewModel.state)
    }
}
```

This works at runtime, but the view constructs live dependencies. A preview now has to initialize production SDKs, reach configuration code, and possibly touch the network.

## Modern approach

I inject a small capability at the composition boundary and keep the view model deterministic.

```swift
import SwiftUI

protocol ProfileLoading {
    func loadProfile() async throws -> Profile
}

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var name = "Loading…"
    private let loader: any ProfileLoading

    init(loader: any ProfileLoading) {
        self.loader = loader
    }

    func load() async {
        do { name = try await loader.loadProfile().name }
        catch { name = "Unavailable" }
    }
}

struct ProfileView: View {
    @StateObject private var viewModel: ProfileViewModel

    init(loader: any ProfileLoading) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(loader: loader))
    }

    var body: some View {
        Text(viewModel.name)
            .task { await viewModel.load() }
    }
}

private struct PreviewLoader: ProfileLoading {
    func loadProfile() async throws -> Profile {
        Profile(name: "Alex")
    }
}

#Preview("Loaded") {
    ProfileView(loader: PreviewLoader())
}
```

The important move is not the mock. It is making the production dependency explicit. The same constructor accepts `LiveProfileLoader` from the app composition root and `PreviewLoader` from the preview.

## Migration strategy

1. Start with one screen whose preview is currently unreliable.
2. Extract only the dependency that creates the pain—networking, persistence, clock, or feature flags.
3. Inject a protocol or closure into the view model; do not introduce a global service locator.
4. Add loaded, empty, and failure previews so visual states become cheap to inspect.
5. Move construction of live implementations upward into the app or feature coordinator.

## Production notes

- Keep preview fixtures local and boring. Their job is legibility, not a second test suite.
- Use static data for previews; async delays make canvas feedback worse.
- If a view has many collaborators, inject a presentation model rather than teaching the view about every service.
- A preview that needs the full app container is useful evidence that the composition boundary is too low.

I now treat a fast, deterministic preview as an architectural smoke test: if I cannot construct the screen with simple inputs, the screen probably owns responsibilities that belong elsewhere.
