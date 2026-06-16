import Foundation

/*
 Route Strategies for Navigation

 I keep seeing the same failure mode in iOS codebases: navigation starts simple,
 then one coordinator grows a giant switch statement and becomes the place where
 product experiments, dependency wiring, and presentation policy all get mixed together.

 Legacy approach
 - One coordinator owns every route.
 - Each new screen adds another case and another branch.
 - Feature flags and auth checks leak into the same function that pushes view controllers.

 Modern approach
 - I model each route as a strategy object with one job: decide if it can handle the route,
   then build the screen using injected dependencies.
 - The router becomes composition instead of conditionals.
 - Feature-specific rules stay close to the feature instead of a central god object.

 Migration strategy
 1. Keep the existing coordinator as the fallback handler.
 2. Extract one stable flow at a time into a RouteHandler.
 3. Register handlers in priority order so experiments can override defaults safely.
 4. Move analytics and auth checks into handlers, then delete the old switch branches.

 Production notes
 - Priority matters. Put narrow, feature-flagged handlers before broad defaults.
 - Keep handlers side-effect light; build screens and return decisions, don't mutate global state.
 - Test route selection separately from view construction so failures are obvious.
 */

struct AppContext {
    let isLoggedIn: Bool
    let hasNewCheckout: Bool
}

enum AppRoute: Equatable {
    case home
    case profile(userID: String)
    case checkout(cartID: String)
}

struct Screen: CustomStringConvertible, Equatable {
    let name: String
    var description: String { name }
}

protocol RouteHandler {
    var priority: Int { get }
    func canHandle(_ route: AppRoute, context: AppContext) -> Bool
    func buildScreen(for route: AppRoute, context: AppContext) -> Screen
}

struct NewCheckoutHandler: RouteHandler {
    let priority = 100

    func canHandle(_ route: AppRoute, context: AppContext) -> Bool {
        guard case .checkout = route else { return false }
        return context.isLoggedIn && context.hasNewCheckout
    }

    func buildScreen(for route: AppRoute, context: AppContext) -> Screen {
        guard case let .checkout(cartID) = route else { return Screen(name: "Invalid") }
        return Screen(name: "NewCheckout(cart: \(cartID))")
    }
}

struct ProfileHandler: RouteHandler {
    let priority = 80

    func canHandle(_ route: AppRoute, context: AppContext) -> Bool {
        guard case .profile = route else { return false }
        return context.isLoggedIn
    }

    func buildScreen(for route: AppRoute, context: AppContext) -> Screen {
        guard case let .profile(userID) = route else { return Screen(name: "Invalid") }
        return Screen(name: "Profile(user: \(userID))")
    }
}

struct DefaultHandler: RouteHandler {
    let priority = 0

    func canHandle(_ route: AppRoute, context: AppContext) -> Bool { true }

    func buildScreen(for route: AppRoute, context: AppContext) -> Screen {
        switch route {
        case .home:
            return Screen(name: "Home")
        case let .profile(userID):
            // A fallback keeps legacy behavior alive while I migrate feature-by-feature.
            return Screen(name: "LegacyProfile(user: \(userID))")
        case let .checkout(cartID):
            return Screen(name: "LegacyCheckout(cart: \(cartID))")
        }
    }
}

struct Router {
    private let handlers: [RouteHandler]

    init(handlers: [RouteHandler]) {
        self.handlers = handlers.sorted { $0.priority > $1.priority }
    }

    func resolve(_ route: AppRoute, context: AppContext) -> Screen {
        for handler in handlers where handler.canHandle(route, context: context) {
            return handler.buildScreen(for: route, context: context)
        }
        return Screen(name: "Unhandled")
    }
}

@main
struct LessonDemo {
    static func main() {
        let router = Router(handlers: [DefaultHandler(), ProfileHandler(), NewCheckoutHandler()])
        let context = AppContext(isLoggedIn: true, hasNewCheckout: true)

        let screens = [
            router.resolve(.home, context: context),
            router.resolve(.profile(userID: "42"), context: context),
            router.resolve(.checkout(cartID: "CART-9"), context: context)
        ]

        // Keeping the demo inside @main makes the file type-check cleanly with -parse-as-library.
        _ = screens
    }
}
