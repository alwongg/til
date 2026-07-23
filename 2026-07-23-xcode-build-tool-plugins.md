# Make generated Swift a build-graph citizen with an Xcode Build Tool Plugin

When I inherit an iOS target with generated Swift checked into Git, the recurring failure mode is not the generator itself. It is drift: a schema changes, someone forgets to regenerate, and the app compiles against an old client or asset accessor.

My default is to move deterministic generation into SwiftPM's build graph. An Xcode Build Tool Plugin gives the generator declared inputs and outputs, so Xcode can rerun it only when something relevant changes.

## Legacy approach: a script people have to remember

```sh
# Scripts/generate-api.sh
./tools/api-generator Specs/API.yaml > Sources/Generated/APIClient.swift
```

This works locally, but it depends on convention. It also writes into the source tree, so CI and every developer need matching tooling and a clean working tree becomes noisy.

## Modern approach: declare the command to SwiftPM

I keep the generator as an executable target and expose it through a build-tool plugin:

```swift
// Plugins/APIGeneratorPlugin/plugin.swift
import PackagePlugin

@main
struct APIGeneratorPlugin: BuildToolPlugin {
    func createBuildCommands(
        context: PluginContext,
        target: Target
    ) throws -> [Command] {
        let input = target.directory.appending("Specs/API.yaml")
        let output = context.pluginWorkDirectory
            .appending("Generated")
            .appending("APIClient.swift")

        return [
            .buildCommand(
                displayName: "Generate API client for \(target.name)",
                executable: try context.tool(named: "api-generator").path,
                arguments: [input.string, output.string],
                inputFiles: [input],
                outputFiles: [output]
            )
        ]
    }
}
```

The important part is not the plugin syntax; it is the contract. `inputFiles` and `outputFiles` make the work visible to the build system. The generated file lives in the plugin work directory, not in `Sources/`, and is compiled with the target output.

A minimal package shape looks like this:

```swift
// Package.swift (relevant targets)
.plugin(name: "APIGeneratorPlugin", capability: .buildTool()),
.executableTarget(name: "api-generator"),
.target(
    name: "Networking",
    plugins: [.plugin(name: "APIGeneratorPlugin")]
)
```

## Migration strategy

1. **Make generation deterministic.** Same input and generator version must produce the same bytes. Sort collections and avoid timestamps in output.
2. **Run it in CI before wiring it into Xcode.** I verify the generator's error messages, exit codes, and fixture coverage first.
3. **Move generated files out of source control.** I remove them only after every consumer gets the plugin through the package dependency.
4. **Add the plugin to the package target.** Xcode discovers package plugins when the package is attached to the project; I do not add a second Run Script phase as a fallback.
5. **Keep an escape hatch for diagnosis.** The generator executable should still run directly against a fixture so failures can be reproduced outside a full app build.

## Production notes

- I pin the generator's dependencies and treat its output as part of the build contract. A generator upgrade gets a focused review just like a compiler upgrade.
- I keep inputs narrow. Pointing a command at an entire repository makes incremental builds unpredictable.
- I make failures actionable: include the source path, the invalid field, and a suggested fix. A plugin error is often encountered by someone who did not write the schema.
- I use plugins for build-time artifacts, not app configuration. Runtime secrets and environment-specific values belong in CI configuration or a secure runtime path.

The payoff is boring in the best way: no stale generated Swift, no ritual script step, and a build graph that explains when regeneration happens.
