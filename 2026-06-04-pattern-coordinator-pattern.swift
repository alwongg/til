import SwiftUI

enum AppRoute: Hashable {
    case product(id: UUID)
    case checkout(cartID: UUID)
}

@MainActor
final class AppCoordinator: ObservableObject {
    @Published var path: [AppRoute] = []

    func showProduct(id: UUID) {
        path.append(.product(id: id))
    }

    func startCheckout(cartID: UUID) {
        // I keep navigation decisions here so feature views stay focused on intent,
        // not on how many pushes, sheets, or deep-link branches are needed.
        path.append(.checkout(cartID: cartID))
    }

    func reset() {
        path.removeAll()
    }
}

struct RootView: View {
    @StateObject private var coordinator = AppCoordinator()

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            Button("Open featured product") {
                coordinator.showProduct(id: UUID())
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .product(let id):
                    ProductView(productID: id, onBuy: { coordinator.startCheckout(cartID: UUID()) })
                case .checkout(let cartID):
                    Text("Checkout for cart: \(cartID.uuidString.prefix(6))")
                }
            }
        }
    }
}

struct ProductView: View {
    let productID: UUID
    let onBuy: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Product \(productID.uuidString.prefix(6))")
            Button("Buy now", action: onBuy)
        }
    }
}

// I reach for a coordinator when flows span multiple screens or entry points.
// In production it gives me one place to handle deep links, experiments, and recovery paths.