# From Run Script Drift to Xcode Build Tool Plugins

I used to solve small build-time problems with another Run Script phase.
Generate mocks, validate assets, lint localization keys, fail the build if an input file changed shape — it was always tempting to drop a shell script into the target and move on. That works for a while, but it scales badly. Scripts accumulate hidden dependencies, Xcode cannot reason about their inputs well, and incremental builds get noisy fast.

## Legacy approach

The older setup usually looked something like this:

```bash
if [ "$CONFIGURATION" = "Debug" ]; then
  python3 Scripts/generate_localization_accessors.py
  python3 Scripts/check_design_tokens.py
fi
```

That approach has a few recurring problems:

- the dependency graph lives in shell, not in Xcode's model
- inputs and outputs are easy to forget, so incremental builds rerun more than they should
- scripts depend on whatever happens to be installed on the machine or CI image
- failures are often hard to diagnose because the script is just a long stream of text in the build log

I have shipped plenty of code with this setup, but I do not trust it once the project gets bigger than one target and one person touching build tooling.

## Modern approach

When the job is really a build transformation or validation step, I prefer moving it into a Swift package plugin so the behavior is versioned, typed, and explicit.

A small package structure can look like this:

```text
BuildTools/
├── Package.swift
├── Plugins/
│   └── ValidateFeatureFlags/
│       └── ValidateFeatureFlagsPlugin.swift
├── Sources/
│   └── FeatureFlagValidator/
│       └── main.swift
└── Config/
    └── feature-flags.json
```

`Package.swift` wires the executable and the plugin together:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BuildTools",
    products: [
        .plugin(name: "ValidateFeatureFlags", targets: ["ValidateFeatureFlags"]),
        .executable(name: "feature-flag-validator", targets: ["FeatureFlagValidator"])
    ],
    targets: [
        .executableTarget(
            name: "FeatureFlagValidator"
        ),
        .plugin(
            name: "ValidateFeatureFlags",
            capability: .buildTool(),
            dependencies: ["FeatureFlagValidator"]
        )
    ]
)
```

The plugin declares exactly what should run during the build:

```swift
import PackagePlugin

@main
struct ValidateFeatureFlagsPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let config = context.package.directory.appending("Config/feature-flags.json")
        let output = context.pluginWorkDirectory.appending("feature-flag-validation.txt")
        let tool = try context.tool(named: "feature-flag-validator")

        return [
            .buildCommand(
                displayName: "Validate feature flag definitions",
                executable: tool.path,
                arguments: [config.string, output.string],
                inputFiles: [config],
                outputFiles: [output]
            )
        ]
    }
}
```

The executable stays tiny and testable:

```swift
import Foundation

struct FeatureFlag: Decodable {
    let key: String
    let defaultValue: Bool
}

@main
struct FeatureFlagValidator {
    static func main() throws {
        let arguments = CommandLine.arguments
        guard arguments.count == 3 else {
            throw ValidationError.usage
        }

        let inputURL = URL(fileURLWithPath: arguments[1])
        let outputURL = URL(fileURLWithPath: arguments[2])
        let data = try Data(contentsOf: inputURL)
        let flags = try JSONDecoder().decode([FeatureFlag].self, from: data)

        let duplicateKeys = Dictionary(grouping: flags, by: \ .key)
            .filter { $0.value.count > 1 }
            .map(\ .key)

        guard duplicateKeys.isEmpty else {
            throw ValidationError.duplicateKeys(duplicateKeys)
        }

        try "validated \(flags.count) feature flags".write(to: outputURL, atomically: true, encoding: .utf8)
    }
}

enum ValidationError: Error, CustomStringConvertible {
    case usage
    case duplicateKeys([String])

    var description: String {
        switch self {
        case .usage:
            return "Expected input and output paths."
        case .duplicateKeys(let keys):
            return "Duplicate feature flag keys: \(keys.joined(separator: ", "))"
        }
    }
}
```

The important shift is not just "rewrite bash in Swift." The real win is that the build step becomes part of Xcode's dependency model. Inputs and outputs are explicit. The tool version ships with the repo. The failure mode is specific instead of being buried in a generic script phase.

## Migration strategy

When I migrate from scripts to plugins, I do it in this order:

1. pick one deterministic script first, usually validation or code generation with a single config input
2. define the real inputs and outputs before writing any plugin code, because that is what makes incremental builds behave
3. move the script logic into a small executable target that I can run locally outside Xcode
4. wrap the executable with a build tool plugin only after the CLI behavior is stable
5. compare clean and incremental build times so I can prove the change improved signal instead of just changing syntax

I keep environment-dependent work out of plugins when possible. If the tool needs network access, secrets, or machine-specific setup, it usually does not belong in the build graph.

## Production notes

- Keep plugins fast. If a step takes seconds on every build, I feel it immediately in iteration speed.
- Prefer validation and code generation jobs that are deterministic from checked-in inputs.
- Treat plugin diagnostics like product UX. A precise error message saves far more time than a clever implementation.
- Use the plugin work directory for generated intermediates instead of polluting the source tree.
- If the team still needs a script for CI orchestration, keep the build logic in the executable target and let CI call the same binary instead of forking behavior.

The big lesson for me is that build tooling deserves the same engineering discipline as app code. Once I move transformations into typed, versioned tools, the project becomes easier to debug, easier to review, and less dependent on whoever last edited a shell script in a hurry.
