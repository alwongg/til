import Foundation

// I use a coordinator when navigation starts to leak out of feature views.
// The goal is to keep flow decisions in one place so screens stay testable.

protocol Screen: CustomStringConvertible {}

struct HomeScreen: Screen { let description = "Home" }
struct DetailScreen: Screen {
    let itemID: UUID
    var description: String { "Detail(\(itemID.uuidString.prefix(6)))" }
}

final class AppCoordinator {
    private(set) var path: [Screen] = [HomeScreen()]

    func showDetail(for itemID: UUID) {
        path.append(DetailScreen(itemID: itemID))
    }

    func finishDetail() {
        guard path.count > 1 else { return }
        path.removeLast()
    }
}

let coordinator = AppCoordinator()
let id = UUID()
coordinator.showDetail(for: id)
print(coordinator.path.map(\.description))
coordinator.finishDetail()
print(coordinator.path.map(\.description))

// In production I usually inject child coordinators for auth, tabs, or checkout.
// That keeps feature modules dumb and makes deep-link handling much easier to test.
