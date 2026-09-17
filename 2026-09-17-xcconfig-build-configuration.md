# I stopped hiding environment configuration inside Xcode projects

I treat build configuration as product code. When it lives as scattered values in Xcode's Build Settings UI, it is hard to review, easy to overwrite in a merge, and unclear which environment is actually shipping.

## The legacy approach

The usual setup starts with `Debug` and `Release`, then adds SDK keys, bundle suffixes, API hosts, and feature flags directly in the project editor. That works until a second target, a staging environment, or CI is involved. I have to click through screens to answer a simple question: *what does this archive use?*

## The modern approach: layered `.xcconfig` files

I keep shared values in one file and override only environment-specific values:

```xcconfig
// Config/Base.xcconfig
PRODUCT_BUNDLE_IDENTIFIER = com.alwongg.product
MARKETING_VERSION = 1.0
CURRENT_PROJECT_VERSION = 42
SWIFT_STRICT_CONCURRENCY = complete

// Config/Debug.xcconfig
#include "Base.xcconfig"
APP_ENVIRONMENT = debug
API_BASE_URL = https:/$()/dev-api.example.com
PRODUCT_BUNDLE_IDENTIFIER = $(inherited).debug

// Config/Release.xcconfig
#include "Base.xcconfig"
APP_ENVIRONMENT = production
API_BASE_URL = https:/$()/api.example.com
```

The `$()` in `https:/$()/` deliberately escapes the `//` comment syntax in an xcconfig file. I then expose only non-secret values through `Info.plist`:

```xml
<key>APIBaseURL</key>
<string>$(API_BASE_URL)</string>
<key>AppEnvironment</key>
<string>$(APP_ENVIRONMENT)</string>
```

At runtime, I read the resolved values once and fail loudly in development if the wiring is incomplete:

```swift
struct AppConfiguration {
    let apiBaseURL: URL
    let environment: String

    init(bundle: Bundle = .main) {
        guard
            let urlString = bundle.object(forInfoDictionaryKey: "APIBaseURL") as? String,
            let apiBaseURL = URL(string: urlString),
            let environment = bundle.object(forInfoDictionaryKey: "AppEnvironment") as? String
        else {
            preconditionFailure("Missing or invalid build configuration")
        }

        self.apiBaseURL = apiBaseURL
        self.environment = environment
    }
}
```

## Migration strategy

1. Create `Base.xcconfig`, then move one stable setting at a time.
2. Add `Debug.xcconfig` and `Release.xcconfig`; assign each in the target's **Configuration** inspector.
3. Move placeholders into `Info.plist` so Swift does not know about build-setting names.
4. Print the resolved environment at app launch in Debug builds and verify an archive before deleting the old UI values.
5. Keep secrets out of source-controlled xcconfig files. CI should inject those through a generated ignored config or build-setting overrides.

## Production notes

- Configurations are not environments by themselves. I use explicit names such as `Debug-Staging` and `Release-Production` once the app needs both axes.
- User-defined settings flow to every target that inherits them, so extensions need deliberate overrides rather than accidental access to the host app's configuration.
- Treat `Info.plist` as the narrow boundary from build-time configuration to runtime code. It makes configuration searchable, testable, and reviewable.
- Before distributing, inspect the archived app's resolved `Info.plist`; the source file alone cannot prove which substitutions the build used.
