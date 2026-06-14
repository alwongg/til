# Why I Keep Transport Details at the Repository Edge

One architecture smell I notice quickly now is when feature code starts speaking HTTP, decoding JSON, and shaping view state all in the same place.

It feels efficient at first because the data is "right there." But a few months later, the feature stops feeling like product code and starts feeling like a pile of transport decisions that leaked too far inward.

My rule is simple: repositories can know how data gets fetched and decoded; features should mostly know what the app means to do with it.

## Legacy approach

This is the kind of view model I try not to grow anymore:

```swift
import Foundation
import SwiftUI

struct UserDTO: Decodable {
    let id: Int
    let name: String
    let isPro: Bool
}

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var title = ""
    @Published private(set) var badgeText: String?
    @Published private(set) var errorMessage: String?

    func loadProfile() async {
        do {
            let url = URL(string: "https://example.com/profile")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let dto = try JSONDecoder().decode(UserDTO.self, from: data)

            title = dto.name
            badgeText = dto.isPro ? "PRO" : nil
        } catch {
            errorMessage = "Couldn't load profile."
        }
    }
}

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()

    var body: some View {
        VStack(spacing: 12) {
            Text(viewModel.title)
                .font(.title)

            if let badgeText = viewModel.badgeText {
                Text(badgeText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.15))
                    .clipShape(Capsule())
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
        }
        .task {
            await viewModel.loadProfile()
        }
    }
}
```

The issue isn't that this code is broken. The issue is that the feature owns too many responsibilities at once:

- transport details (`URLSession`, URLs, status assumptions)
- decoding shape (`UserDTO`)
- domain interpretation (`isPro` becomes badge behavior)
- presentation state

Once that pattern spreads, every screen becomes its own tiny networking layer.

## Modern approach

I prefer pushing transport knowledge outward and pulling domain meaning inward.

```swift
import Foundation
import SwiftUI

struct UserProfile: Sendable {
    let displayName: String
    let tier: MembershipTier
}

enum MembershipTier: Sendable {
    case free
    case pro

    var badgeText: String? {
        switch self {
        case .free:
            return nil
        case .pro:
            return "PRO"
        }
    }
}

protocol ProfileRepository: Sendable {
    func fetchProfile() async throws -> UserProfile
}

private struct UserDTO: Decodable {
    let id: Int
    let name: String
    let isPro: Bool
}

struct LiveProfileRepository: ProfileRepository {
    let session: URLSession
    let decoder: JSONDecoder
    let endpoint: URL

    init(
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder(),
        endpoint: URL = URL(string: "https://example.com/profile")!
    ) {
        self.session = session
        self.decoder = decoder
        self.endpoint = endpoint
    }

    func fetchProfile() async throws -> UserProfile {
        let (data, _) = try await session.data(from: endpoint)
        let dto = try decoder.decode(UserDTO.self, from: data)

        return UserProfile(
            displayName: dto.name,
            tier: dto.isPro ? .pro : .free
        )
    }
}

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var title = ""
    @Published private(set) var badgeText: String?
    @Published private(set) var errorMessage: String?

    private let repository: any ProfileRepository

    init(repository: any ProfileRepository) {
        self.repository = repository
    }

    func loadProfile() async {
        do {
            let profile = try await repository.fetchProfile()
            title = profile.displayName
            badgeText = profile.tier.badgeText
            errorMessage = nil
        } catch {
            title = ""
            badgeText = nil
            errorMessage = "Couldn't load profile."
        }
    }
}

struct ProfileScreen: View {
    @StateObject private var viewModel: ProfileViewModel

    init(viewModel: @autoclosure @escaping () -> ProfileViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(viewModel.title)
                .font(.title)

            if let badgeText = viewModel.badgeText {
                Text(badgeText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.15))
                    .clipShape(Capsule())
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
        }
        .task {
            await viewModel.loadProfile()
        }
    }
}

@main
struct DemoApp: App {
    var body: some Scene {
        WindowGroup {
            ProfileScreen(
                viewModel: ProfileViewModel(
                    repository: LiveProfileRepository()
                )
            )
        }
    }
}
```

What changed is subtle but important:

- the repository owns transport and decoding
- the view model owns presentation state and user-facing failure handling
- the domain model carries app meaning instead of raw API shape

That separation keeps the screen readable even when the backend gets messier.

## Migration strategy

The way I usually refactor toward this in a production app is intentionally incremental:

1. Start by identifying one view model that talks directly to `URLSession` or `JSONDecoder`.
2. Move the fetch-and-decode path into a repository without changing the feature's external behavior.
3. Introduce one domain model that reflects product language, not API field names.
4. Keep DTOs private to the repository layer so they stop leaking into UI decisions.
5. Only after the boundary is clear, add better caching, retries, mocks, or alternate data sources.

That order matters because it turns architecture work into a sequence of small seam-creating changes instead of a sweeping rewrite.

## Production notes

- I keep DTO types close to the repository because they usually change for backend reasons, not product reasons.
- If a screen needs three endpoints and a merge step, that complexity belongs in repository or use-case territory before it reaches SwiftUI.
- I try not to expose transport-specific errors directly to views; features usually need product-level states, not `URLError` trivia.
- Repositories do not need to become giant god objects. A boring, feature-scoped repository is usually enough.
- When tests get easier after a refactor, that's usually a signal the boundary improved for real and not just cosmetically.

The payoff is that feature code starts reading like app behavior again instead of network plumbing with a `@Published` wrapper around it.
