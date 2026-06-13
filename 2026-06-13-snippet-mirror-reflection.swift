import Foundation

struct FeatureFlag {
    let name: String
    let isEnabled: Bool
}

struct ReleaseConfig {
    let build: String
    let flags: [FeatureFlag]
    let apiBaseURL: URL
}

func debugSummary<T>(for value: T) -> String {
    let mirror = Mirror(reflecting: value)

    // When I'm debugging model shape mismatches, Mirror gives me a quick, dependency-free snapshot.
    let parts = mirror.children.compactMap { child -> String? in
        guard let label = child.label else { return nil }
        return "\(label)=\(child.value)"
    }

    return "\(mirror.subjectType): " + parts.joined(separator: ", ")
}

@main
struct MirrorReflectionDemo {
    static func main() {
        let config = ReleaseConfig(
            build: "2026.06.13",
            flags: [
                FeatureFlag(name: "NewSearch", isEnabled: true),
                FeatureFlag(name: "VerboseLogs", isEnabled: false)
            ],
            apiBaseURL: URL(string: "https://api.example.com")!
        )

        print(debugSummary(for: config))
    }
}
