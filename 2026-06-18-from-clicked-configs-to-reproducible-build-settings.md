# From clicked configs to reproducible build settings

I used to treat Xcode build settings like a control panel: click around, flip a flag, get the build green, and move on. It worked until I had multiple schemes, a staging backend, SwiftUI previews, and CI all disagreeing about what the app was supposed to do.

## Legacy approach
- I changed values directly in the project editor.
- Debug, Release, and CI drifted over time.
- Secrets and environment toggles leaked into ad-hoc user settings.
- When a teammate hit a weird build, the fix was usually “match my local Xcode.”

## Modern approach
I prefer pushing configuration into versioned `xcconfig` files and keeping schemes intentionally thin.

```xcconfig
// Config/Base.xcconfig
SWIFT_STRICT_CONCURRENCY = complete
OTHER_SWIFT_FLAGS = $(inherited) -DAPPSTORE
API_BASE_URL = https://api.example.com

// Config/Debug.xcconfig
#include "Base.xcconfig"
SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG MOCKS
API_BASE_URL = https://staging-api.example.com
```

Then I read those values from code through one small boundary instead of sprinkling literals everywhere.

```swift
enum AppConfig {
    static let apiBaseURL: URL = {
        let raw = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String ?? ""
        guard let url = URL(string: raw) else {
            preconditionFailure("Missing API_BASE_URL")
        }
        return url
    }()
}
```

## Migration strategy
1. Move environment-specific values out of the project UI into `Base`, `Debug`, and `Release` xcconfigs.
2. Keep compile-time flags narrow. I only use them for code shape differences, not everyday runtime behavior.
3. Route Info.plist lookups through a typed config surface like `AppConfig` so the rest of the app stays boring.
4. Make CI build the same scheme/configuration pair I use locally with `xcodebuild`, not a special snowflake lane.

## Production notes
- SwiftUI previews get more reliable when preview-only dependencies are injected through scheme/config boundaries instead of global singletons.
- If a value changes per environment but not per binary, I choose runtime config over compiler flags.
- If a setting matters to shipping quality, I want it reviewable in git, not hidden in `.pbxproj` churn or someone’s local DerivedData folklore.

The transformation for me is simple: stop treating Xcode as the source of truth. Xcode is the editor. The repo is the product memory.
