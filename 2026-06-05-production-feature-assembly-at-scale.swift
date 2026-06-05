import Foundation

/*
 # From Global Service Locator to Feature Assembly for Production iOS

 I still see scaling problems in iOS codebases get blamed on UIKit vs SwiftUI, or MVC vs MVVM, when the real issue is usually dependency shape.

 A small app survives with global singletons because every feature can reach for whatever it wants. A growing app pays for that convenience later with hidden coupling, test setup pain, and rollout risk.

 When I want an app to keep shipping cleanly as teams and features multiply, I move from a service locator mindset to explicit feature assembly.

 ## Legacy approach

 This is the kind of structure I try to shrink over time:

 ```swift
 enum AppServices {
     static let api = APIClient.shared
     static let analytics = Analytics.shared
     static let flags = RemoteFlags.shared
 }

 final class CheckoutViewModel {
     func load() async throws {
         let cart = try await AppServices.api.fetchCart()
         AppServices.analytics.track("checkout_loaded")
         if AppServices.flags.isEnabled("new_checkout") {
             // branch product behavior here
         }
     }
 }
 ```

 It feels efficient at first, but production complexity spreads fast:
 - every feature can depend on everything
 - test setup becomes partial and leaky
 - experiments are hard to localize
 - previews and local demos stop being representative
 - ownership boundaries fade as the app grows

 ## Modern approach

 I prefer assembling each feature with only the dependencies it actually needs.
 */

protocol CartAPI: Sendable {
    func fetchCart() async throws -> Cart
}

protocol AnalyticsTracking: Sendable {
    func track(_ event: String)
}

protocol FeatureFlags: Sendable {
    func isEnabled(_ key: String) -> Bool
}

struct Cart: Sendable {
    let id: UUID
    let itemCount: Int
}

struct LiveCartAPI: CartAPI {
    func fetchCart() async throws -> Cart {
        try await Task.sleep(for: .milliseconds(20))
        return Cart(id: UUID(), itemCount: 3)
    }
}

struct ConsoleAnalytics: AnalyticsTracking {
    func track(_ event: String) {
        print("analytics=\(event)")
    }
}

struct StaticFlags: FeatureFlags {
    let enabledKeys: Set<String>

    func isEnabled(_ key: String) -> Bool {
        enabledKeys.contains(key)
    }
}

struct CheckoutDependencies: Sendable {
    let api: any CartAPI
    let analytics: any AnalyticsTracking
    let flags: any FeatureFlags
}

struct CheckoutState: Sendable {
    let title: String
    let itemCountText: String
    let usesExperimentalFlow: Bool
}

struct LoadCheckoutUseCase: Sendable {
    let dependencies: CheckoutDependencies

    func execute() async throws -> CheckoutState {
        let cart = try await dependencies.api.fetchCart()
        let usesExperimentalFlow = dependencies.flags.isEnabled("new_checkout")

        dependencies.analytics.track("checkout_loaded")

        return CheckoutState(
            title: usesExperimentalFlow ? "Checkout v2" : "Checkout",
            itemCountText: "Items: \(cart.itemCount)",
            usesExperimentalFlow: usesExperimentalFlow
        )
    }
}

@MainActor
final class CheckoutViewModel {
    private let loadCheckout: LoadCheckoutUseCase

    private(set) var title = ""
    private(set) var subtitle = ""
    private(set) var isExperimentEnabled = false

    init(loadCheckout: LoadCheckoutUseCase) {
        self.loadCheckout = loadCheckout
    }

    func load() async {
        do {
            let state = try await loadCheckout.execute()
            title = state.title
            subtitle = state.itemCountText
            isExperimentEnabled = state.usesExperimentalFlow
        } catch {
            title = "Checkout unavailable"
            subtitle = "Retry when cart data is reachable."
            isExperimentEnabled = false
        }
    }
}

@MainActor
struct CheckoutFeatureAssembly {
    let dependencies: CheckoutDependencies

    func makeViewModel() -> CheckoutViewModel {
        let useCase = LoadCheckoutUseCase(dependencies: dependencies)
        return CheckoutViewModel(loadCheckout: useCase)
    }
}

@main
enum Demo {
    static func main() async {
        let assembly = CheckoutFeatureAssembly(
            dependencies: CheckoutDependencies(
                api: LiveCartAPI(),
                analytics: ConsoleAnalytics(),
                flags: StaticFlags(enabledKeys: ["new_checkout"])
            )
        )

        let viewModel = assembly.makeViewModel()
        await viewModel.load()

        print(viewModel.title)
        print(viewModel.subtitle)
        print("experiment=\(viewModel.isExperimentEnabled)")
    }
}

/*
 What I like about this shape:
 - dependency reach is explicit, so feature growth stays easier to reason about
 - the assembly point is where I swap live, preview, and test implementations
 - product experiments stay local to the feature instead of leaking app-wide
 - use cases carry workflow decisions while the view model goes back to presentation

 ## Migration strategy

 I usually move toward this setup in four passes:

 1. Replace direct singleton access with small protocols at the feature edge.
 2. Group only the truly needed dependencies into a feature-scoped container.
 3. Move orchestration into one or two use cases before touching UI structure.
 4. Add feature assemblies for previews, tests, and experiments so the seams get exercised daily.

 ## Production notes

 - I keep the app environment broad, but feature dependencies narrow.
 - If a dependency is used by one feature, I inject it there instead of promoting it globally too early.
 - Assembly code is allowed to look boring. That is usually a sign the runtime graph is understandable.
 - When teams grow, explicit assembly is one of the cheapest ways I know to keep ownership clear.
 */
