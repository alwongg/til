import SwiftUI

// I use a coordinator when navigation starts leaking into every view model.
// The payoff is simple: screens describe intent, and one object owns routing.

enum AppRoute: Hashable {
    case profile(UUID)
    case settings
}

@MainActor
final class AppCoordinator: ObservableObject {
    @Published var path = NavigationPath()

    func showProfile(id: UUID) {
        path.append(AppRoute.profile(id))
    }

    func showSettings() {
        path.append(AppRoute.settings)
    }

    func resetToRoot() {
        path = NavigationPath()
    }
}

struct HomeView: View {
    @StateObject private var coordinator = AppCoordinator()

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            VStack(spacing: 16) {
                Button("Open profile") { coordinator.showProfile(id: UUID()) }
                Button("Settings") { coordinator.showSettings() }
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .profile(let id): Text("Profile: \(id.uuidString.prefix(8))")
                case .settings: Text("Settings")
                }
            }
        }
    }
}
