# Modern Xcode Build Tool Plugins

I used to treat Xcode builds as a place where a few hand-written Run Script phases could do anything I needed: codegen, linting, formatting, asset checks, even little deployment guardrails. That works for a while, but it turns into a reliability tax. Scripts drift between targets, local paths leak into the build, and CI behaves differently from my laptop.

## Legacy approach

The old shape usually looks like this:

- a Run Script phase with hard-coded paths
- tools installed globally with Homebrew or Mint
- environment assumptions that only exist on one machine
- no clear declaration of inputs and outputs

That creates three production problems:

1. incremental builds get slower because Xcode cannot reason about the script well
2. onboarding gets worse because every engineer has to reproduce the same toolchain setup
3. CI failures become noisy because the script's contract is implicit instead of modeled

## Modern approach

Build Tool Plugins push that work into a first-class Swift Package construct. Instead of hiding automation in a shell phase, I can package it with declared intent and keep the logic versioned alongside the code.

```swift
import PackagePlugin

@main
struct SwiftLintPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let tool = try context.tool(named: "swiftlint")
        let output = context.pluginWorkDirectory.appending("swiftlint-report.txt")

        return [
            .buildCommand(
                displayName: "Linting \(target.name) with SwiftLint",
                executable: tool.path,
                arguments: [
                    "lint",
                    "--path", target.directory.string,
                    "--reporter", "xcode"
                ],
                outputFiles: [output]
            )
        ]
    }
}
```

What I like about this:

- the tool invocation is explicit and reviewable
- the plugin work directory gives Xcode a predictable place for outputs
- the package becomes the distribution boundary, so the same automation runs locally and in CI

## Migration strategy

When I move a project off Run Script phases, I do it in this order:

1. identify scripts that are deterministic and target-scoped
2. convert the script into a packaged tool or wrap an existing binary cleanly
3. declare real outputs so incremental builds stay fast
4. keep one script phase temporarily only if it handles something outside plugin scope
5. remove the old phase after CI has proven parity

The key filter is whether the task belongs to the build graph. If it does, a plugin is usually the better home. If it is account-specific or deployment-specific, I keep it outside Xcode.

## Production notes

- Plugins improve maintainability, but they are not magic: bad tools still cause bad builds.
- I keep plugin work deterministic and avoid network calls entirely.
- If a step mutates source files, I prefer a command plugin or a separate developer command over surprising the build.
- On larger iOS repos, this pattern pays off because it replaces invisible shell glue with typed, testable infrastructure.

The broader lesson for me is that modern Apple tooling is best when I treat build automation as product code, not as a pile of scripts that happened to work once.
