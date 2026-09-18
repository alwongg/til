// Coordinator Pattern: keep navigation out of SwiftUI views
//
// I use a coordinator when a feature has navigation decisions that would otherwise
// leak into views. The view emits intent; the coordinator owns the route. That
// keeps previews simple and makes deep links or alternate flows testable.

import SwiftUI

enum SettingsRoute: Hashable {
    case profile(userID: String)
    case notifications
}

@MainActor
final class SettingsCoordinator: ObservableObject {
    @Published var path: [SettingsRoute] = []

    func showProfile(id: String) {
        path.append(.profile(userID: id))
    }

    func showNotifications() {
        path.append(.notifications)
    }

    func popToRoot() {
        path.removeAll()
    }
}

struct SettingsFlow: View {
    @StateObject private var coordinator = SettingsCoordinator()

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            SettingsView(
                openProfile: { coordinator.showProfile(id: "42") },
                openNotifications: coordinator.showNotifications
            )
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case let .profile(id): ProfileView(userID: id)
                case .notifications: NotificationsView()
                }
            }
        }
    }
}

// These feature views depend on closures, not on NavigationStack or route details.
struct SettingsView: View {
    let openProfile: () -> Void
    let openNotifications: () -> Void
    var body: some View { List { Button("Profile", action: openProfile); Button("Notifications", action: openNotifications) } }
}
struct ProfileView: View { let userID: String; var body: some View { Text("Profile: \(userID)") } }
struct NotificationsView: View { var body: some View { Text("Notifications") } }
