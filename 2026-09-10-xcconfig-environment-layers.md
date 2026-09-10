# I stopped hard-coding environments into Xcode schemes

I used to add a new scheme for every environment: `App Dev`, `App Staging`, `App Production`. It felt explicit, until each scheme accumulated slightly different arguments, bundle identifiers, and signing settings. The differences became invisible configuration drift.

## Legacy approach: schemes carry configuration

A scheme is a good *launcher*, but a poor source of truth. When it owns environment values, I have to inspect the scheme UI to answer basic questions:

- Which API host does this archive use?
- Does staging have a distinct bundle identifier?
- Which values are safe to ship?

That also makes CI fragile: a build command has to know Xcode's scheme names rather than select a build configuration deliberately.

## Modern approach: layer `.xcconfig` files

I keep shared settings in a base file and let each environment override only its differences.

```xcconfig
// Config/Base.xcconfig
PRODUCT_BUNDLE_IDENTIFIER = com.alwongg.product
SWIFT_VERSION = 6.0
API_HOST = api.example.com

// Config/Debug.xcconfig
#include "Base.xcconfig"
PRODUCT_BUNDLE_IDENTIFIER = com.alwongg.product.dev
API_HOST = api-dev.example.com

// Config/Release.xcconfig
#include "Base.xcconfig"
API_HOST = api.example.com
```

Then I expose only the values the app needs through `Info.plist`:

```xml
<key>APIHost</key>
<string>$(API_HOST)</string>
```

```swift
import Foundation

enum AppEnvironment {
    static var apiHost: String {
        guard let host = Bundle.main.object(forInfoDictionaryKey: "APIHost") as? String,
              !host.isEmpty else {
            preconditionFailure("APIHost is missing from the active build configuration")
        }
        return host
    }
}
```

The scheme now chooses a configuration; the configuration defines behaviour. That separation makes local development, archives, and CI use the same contract.

## Migration strategy

1. Inventory every scheme-only setting: launch arguments, preprocessor macros, bundle IDs, endpoint hosts, and feature flags.
2. Move compile-time values into a `Base.xcconfig` plus environment overrides. Keep secrets out of these files; inject those in CI or use a secure runtime configuration path.
3. Attach each `.xcconfig` to its Xcode build configuration in the project inspector.
4. Replace duplicated schemes with a small set that map cleanly to Debug, Staging, and Release configurations.
5. In CI, build the configuration explicitly and archive the same scheme used by distribution.

## Production notes

- Treat `Info.plist` substitution as a public boundary: validate required values at startup so a misconfigured archive fails loudly.
- Prefer one canonical production host. A release configuration pointing at staging is a deployment incident, not a convenience.
- Keep signing identities and provisioning out of `.xcconfig` where Xcode-managed signing is doing the work; configuration files should reduce drift, not recreate it.
- Review `.xcconfig` diffs like code. A one-line endpoint or bundle-ID change can alter the artifact more than a large Swift refactor.

My rule now: schemes decide *how I launch*; `.xcconfig` files decide *what I build*.
