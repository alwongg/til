/*
Slot 1/4 · Architecture Patterns Evolved — Feature-Scoped Composition Root

I keep coming back to the same architecture lesson: global containers age badly.
They feel clean when the app is small, but they slowly turn every feature into a shared-state negotiation.
What scales better for me is a feature-scoped composition root: assemble dependencies once at the boundary,
pass narrow capabilities inward, and keep the feature graph obvious.

Legacy approach
- A view model reaches into singletons or a giant app container.
- Repositories leak across unrelated screens because everything is globally available.
- Tests become awkward because the only replacement point is the entire container.

Modern approach
- Build a small Environment for the feature.
- Inject behavior as focused async closures instead of broad service protocols when the surface area is tiny.
- Let the repository own persistence/network details while the view model coordinates user intent.

Migration strategy
1. Start at one feature boundary instead of rewriting the whole app container.
2. Wrap existing services inside a small Environment so the view model stops importing globals.
3. Collapse one-method protocols into closures when protocol polymorphism is not buying anything.
4. Keep cross-feature sharing in factories, not in the view models.

Production notes
- This pattern reduces mock setup because each test provides only the capabilities it needs.
- It also makes Swift concurrency adoption easier because the async edges are explicit.
- I still use protocols when I have multiple real implementations, but I avoid protocol soup by default.
*/

import Foundation

struct Product: Sendable, Identifiable, Equatable {
    let id: UUID
    let name: String
}

struct ProductsEnvironment: Sendable {
    var fetchProducts: @Sendable () async throws -> [Product]
    var trackScreenView: @Sendable (_ name: String) -> Void
}

actor ProductRepository {
    private let products: [Product]

    init(products: [Product]) {
        self.products = products
    }

    func fetchAll() async throws -> [Product] {
        try await Task.sleep(nanoseconds: 50_000_000)
        return products
    }
}

@MainActor
final class ProductsViewModel {
    private let environment: ProductsEnvironment
    private(set) var products: [Product] = []

    init(environment: ProductsEnvironment) {
        self.environment = environment
    }

    func onAppear() async {
        environment.trackScreenView("products")

        do {
            products = try await environment.fetchProducts()
        } catch {
            products = []
        }
    }
}

@MainActor
enum ProductsFeature {
    static func makeViewModel() -> ProductsViewModel {
        let repository = ProductRepository(products: [
            Product(id: UUID(), name: "Mechanical Keyboard"),
            Product(id: UUID(), name: "USB-C Dock"),
            Product(id: UUID(), name: "Portable Monitor")
        ])

        let environment = ProductsEnvironment(
            fetchProducts: { try await repository.fetchAll() },
            trackScreenView: { screenName in
                print("Tracking screen: \(screenName)")
            }
        )

        return ProductsViewModel(environment: environment)
    }
}

@main
struct DemoApp {
    static func main() async {
        let viewModel = await ProductsFeature.makeViewModel()
        await viewModel.onAppear()
        print(viewModel.products.map(\.name).joined(separator: ", "))
    }
}
