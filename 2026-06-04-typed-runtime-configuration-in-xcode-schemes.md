# From Launch Argument Drift to Typed Runtime Configuration in Xcode Schemes

I used to treat Xcode schemes as a convenient place to sprinkle launch arguments, environment variables, and little debugging toggles whenever I needed them. That was fast in the moment, but after a while the app's runtime behavior depended on a pile of hidden scheme settings that only existed on one machine or one shared scheme. The code compiled fine, but reproducing a bug or validating a feature flag became surprisingly inconsistent.

## Legacy approach

The old setup usually had a few predictable failure modes:

- launch arguments lived in local schemes and never made it into code review
- environment variables were spelled ad hoc, so one typo silently changed app behavior
- preview, test, and debug runs each booted the app differently without a clear contract
- feature flags leaked into random `ProcessInfo` lookups across the codebase

A common smell looked like this:

```swift
import Foundation

let processInfo = ProcessInfo.processInfo

if processInfo.arguments.contains("-useMockAPI") {
    apiClient = MockAPIClient()
} else {
    apiClient = LiveAPIClient()
}

if processInfo.environment["SHOW_EXPERIMENTAL_PAYWALL"] == "1" {
    paywallMode = .experimental
}
```

That works for a quick spike, but it does not scale well. The app starts depending on stringly typed launch state, and nobody can answer which combinations are valid without opening Xcode and clicking through scheme editors.

## Modern approach

Now I prefer to keep schemes thin and make runtime configuration typed. I still use launch arguments and environment variables, but only as an integration boundary. The first thing the app does is decode them into a small configuration model with explicit defaults.

I keep the scheme surface predictable:

```text
App-Debug
- Arguments Passed On Launch:
  - -appEnvironment staging
  - -apiMode mock
  - -uiTesting NO

App-UITests
- Arguments Passed On Launch:
  - -appEnvironment staging
  - -apiMode mock
  - -uiTesting YES
  - -disableAnimations YES
```

Then I map those values into a typed runtime object:

```swift
import Foundation

enum AppEnvironment: String {
    case staging
    case production
}

enum APIMode: String {
    case live
    case mock
}

struct LaunchConfiguration {
    let environment: AppEnvironment
    let apiMode: APIMode
    let isUITesting: Bool
    let disableAnimations: Bool

    static func load(processInfo: ProcessInfo = .processInfo) -> LaunchConfiguration {
        func argumentValue(for flag: String) -> String? {
            guard let index = processInfo.arguments.firstIndex(of: flag) else { return nil }
            let valueIndex = processInfo.arguments.index(after: index)
            guard valueIndex < processInfo.arguments.endIndex else { return nil }
            return processInfo.arguments[valueIndex]
        }

        let environment = AppEnvironment(
            rawValue: argumentValue(for: "-appEnvironment") ?? "production"
        ) ?? .production

        let apiMode = APIMode(
            rawValue: argumentValue(for: "-apiMode") ?? "live"
        ) ?? .live

        let isUITesting = argumentValue(for: "-uiTesting") == "YES"
        let disableAnimations = argumentValue(for: "-disableAnimations") == "YES"

        return LaunchConfiguration(
            environment: environment,
            apiMode: apiMode,
            isUITesting: isUITesting,
            disableAnimations: disableAnimations
        )
    }
}
```

From there, composition gets much cleaner because the rest of the app depends on meaning instead of raw strings:

```swift
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        let config = LaunchConfiguration.load()

        if config.disableAnimations {
            UIView.setAnimationsEnabled(false)
        }

        AppContainer.bootstrap(
            environment: config.environment,
            apiMode: config.apiMode,
            isUITesting: config.isUITesting
        )

        return true
    }
}
```

The big win is reproducibility. A scheme still decides which launch values to inject, but the app owns the interpretation in one place, and tests can assert against that contract.

## Migration strategy

When I clean this up in an older project, I do it in this order:

1. inventory every launch argument and environment variable currently used by the app, UI tests, and previews
2. group them into a few stable concerns like environment, data source, UI testing, and diagnostics
3. replace scattered `ProcessInfo` reads with a single typed loader
4. move feature-specific toggles behind injected dependencies so the configuration model stays small
5. keep scheme names descriptive and verify them in CI or at least in documented team workflows

The important part is resisting the urge to make the configuration model a dumping ground. If every experiment gets its own permanent launch flag, the typed wrapper helps less than it should.

## Production notes

- Shared schemes matter. If the team relies on a scheme, it should be committed and reviewed like source.
- Prefer arguments for explicit run-mode switches and dependency injection for deeper behavior changes.
- Keep UI test launch flags stable. Flaky tests often come from runtime setup drift more than from the view code itself.
- If a value becomes business-critical, move it out of scheme-only configuration and into a stronger source of truth like build configuration or server-driven flags.
- Review scheme changes alongside app startup code because they are two halves of the same runtime contract.

This is one of those Xcode hygiene wins that pays back every week. The app becomes easier to boot in known states, onboarding gets smoother, and debugging stops depending on who happened to remember the right local scheme checkbox.
