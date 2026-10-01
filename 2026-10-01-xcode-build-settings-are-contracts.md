# Stop Treating Xcode Build Settings as a Global Bag of Strings

I used to treat build settings as a place to park whatever the app needed: base URLs, feature flags, bundle identifiers, and signing details. That works until Debug quietly talks to production, a new scheme inherits the wrong entitlement, or CI produces an artifact that nobody can explain.

## Legacy approach: duplicate configuration in code

```swift
struct APIConfiguration {
    #if DEBUG
    let baseURL = URL(string: "https://staging.example.com")!
    #else
    let baseURL = URL(string: "https://api.example.com")!
    #endif
}
```

This couples environment choice to compiler conditions. A `Release` build is not necessarily production: QA, TestFlight, and internal distribution can all use optimized builds with different services. It also invites duplicated `#if` blocks across targets.

## Modern approach: configurations express intent

I define configuration-specific `.xcconfig` files and expose only the values the app needs through `Info.plist`.

```xcconfig
// Config/Debug.xcconfig
#include "Shared.xcconfig"
API_BASE_URL = https:/$()/staging.example.com
APP_DISPLAY_NAME = MyApp Dev

// Config/Release.xcconfig
#include "Shared.xcconfig"
API_BASE_URL = https:/$()/api.example.com
APP_DISPLAY_NAME = MyApp
```

`Shared.xcconfig` owns stable settings such as the marketing version; each environment file owns its deliberate differences. In `Info.plist`, I set `APIBaseURL` to `$(API_BASE_URL)`.

```swift
import Foundation

enum AppConfiguration {
    static var apiBaseURL: URL {
        guard
            let rawValue = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String,
            let url = URL(string: rawValue)
        else {
            preconditionFailure("APIBaseURL must be configured in the active build configuration")
        }
        return url
    }
}
```

The app reads a typed boundary, while Xcode decides the value from the active configuration.

## Migration strategy

1. Inventory every `#if DEBUG` that changes runtime behavior rather than diagnostics.
2. Create `Shared.xcconfig` plus one file per real environment, then assign them in the project’s **Configurations** inspector.
3. Move non-secret values through `Info.plist` substitution and centralize reads in one configuration type.
4. Add a CI check that archives each distributable scheme and prints its resolved build settings.

## Production notes

- Build settings are not secret storage. A value embedded in an app can be extracted; put credentials behind a server or provision them at runtime.
- Keep bundle IDs, entitlements, associated domains, and push environments explicitly scoped per configuration/target. These are release boundaries, not convenience defaults.
- Prefer named configurations such as `Staging`, `Production`, and `QA` over assuming `Debug` and `Release` describe a backend.
- When a scheme should be reproducible, commit the `.xcscheme` and `.xcconfig` files. Local scheme-only changes are configuration drift waiting to happen.

My rule now: code describes how the app behaves; build configuration describes where and how it is allowed to run.
