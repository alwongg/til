import Foundation

// 2026-06-09 — Architecture Patterns Evolved
// Title: From Service Singletons to Composition Roots
//
// I still see iOS features wired through global singletons because it feels fast
// at the start. The cost shows up later when tests leak state, previews need
// production services, and feature setup logic gets scattered across the app.
// When a codebase starts bending that way, I move assembly to an explicit
// composition root and keep feature dependencies scoped.

struct UserProfile: Sendable {
    let id: UUID
    let name: String
}

enum ProfileError: Error {
    case missingUser
}

protocol AnalyticsTracking {
    func track(_ event: String)
}

protocol ProfileRepository {
    func fetchCurrentUser() async throws -> UserProfile
}

// Legacy approach: shared mutable globals. Any screen can reach in, but the app
// loses control over lifecycle, test seams, and dependency boundaries.
final class ServiceLocator {
    static let shared = ServiceLocator()

    var analytics: AnalyticsTracking = ConsoleAnalytics()
    var profileRepository: ProfileRepository = APIProfileRepository()

    private init() {}
}

@MainActor
final class LegacyProfileViewModel {
    private(set) var title = "Loading..."

    func refresh() async {
        do {
            let profile = try await ServiceLocator.shared.profileRepository.fetchCurrentUser()
            title = profile.name
            ServiceLocator.shared.analytics.track("legacy_profile_loaded")
        } catch {
            title = "Unavailable"
        }
    }
}

// Modern approach: one app container builds long-lived dependencies, and each
// feature gets a smaller container with only what it needs.
struct AppContainer {
    let analytics: AnalyticsTracking
    let profileRepository: ProfileRepository

    func makeProfileFeature() -> ProfileFeatureContainer {
        ProfileFeatureContainer(
            loadProfile: LoadProfileUseCase(repository: profileRepository),
            analytics: analytics
        )
    }
}

struct ProfileFeatureContainer {
    let loadProfile: LoadProfileUseCase
    let analytics: AnalyticsTracking

    @MainActor
    func makeViewModel() -> ProfileViewModel {
        ProfileViewModel(loadProfile: loadProfile, analytics: analytics)
    }
}

struct LoadProfileUseCase {
    let repository: ProfileRepository

    func execute() async throws -> UserProfile {
        try await repository.fetchCurrentUser()
    }
}

@MainActor
final class ProfileViewModel {
    private let loadProfile: LoadProfileUseCase
    private let analytics: AnalyticsTracking

    private(set) var title = "Loading..."
    private(set) var subtitle = ""

    init(loadProfile: LoadProfileUseCase, analytics: AnalyticsTracking) {
        self.loadProfile = loadProfile
        self.analytics = analytics
    }

    func refresh() async {
        do {
            let profile = try await loadProfile.execute()
            title = profile.name
            subtitle = "Scoped dependencies make previews and tests predictable."
            analytics.track("profile_loaded")
        } catch {
            title = "Unavailable"
            subtitle = "Keep feature failure local instead of leaking global state."
        }
    }
}

// Migration strategy:
// 1. I keep existing service implementations and only move assembly first.
// 2. I replace global reads with initializer injection at feature boundaries.
// 3. I introduce a small feature container when a screen needs 2-4 dependencies.
// 4. I let the app entry point own long-lived services so tests can swap the whole graph.
struct ProfileScreenBridge {
    let makeViewModel: @MainActor () -> ProfileViewModel

    @MainActor
    func render() async -> String {
        let viewModel = makeViewModel()
        await viewModel.refresh()
        return "\(viewModel.title) — \(viewModel.subtitle)"
    }
}

// Production notes:
// - Composition roots make environment drift obvious because assembly happens in one place.
// - Feature containers stay cheap if they are mostly factories plus narrow policies.
// - I avoid turning the container itself into another singleton; ownership should stay explicit.
// - This pattern pays off most when previews, tests, and app runtime need different wiring.
struct ConsoleAnalytics: AnalyticsTracking {
    func track(_ event: String) {
        print("Analytics event: \(event)")
    }
}

struct APIProfileRepository: ProfileRepository {
    func fetchCurrentUser() async throws -> UserProfile {
        try await Task.sleep(nanoseconds: 50_000_000)
        return UserProfile(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            name: "Alex"
        )
    }
}

@main
struct DemoApp {
    static func main() async {
        let app = AppContainer(
            analytics: ConsoleAnalytics(),
            profileRepository: APIProfileRepository()
        )

        let profileFeature = app.makeProfileFeature()
        let bridge = ProfileScreenBridge(makeViewModel: { profileFeature.makeViewModel() })
        let output = await bridge.render()
        print(output)
    }
}
