import Foundation

/*
# Slot 2/4 — iOS Tip
## Dictionary(grouping:by:)

I use `Dictionary(grouping:by:)` when I want the shape of my data to explain the next screen.
Instead of collecting everything into one flat array and scattering filters through the UI, I group once at the boundary and hand downstream code a structure that already matches the feature.

Production rule I keep in mind: group by a stable, presentation-ready key. If the grouping rule is expensive or inconsistent, I just move the mess to a different layer.
*/

struct Build: CustomStringConvertible {
    let branch: String
    let lane: String
    let durationSeconds: Int

    var description: String {
        "\(branch) [\(lane)] - \(durationSeconds)s"
    }
}

enum BuildDashboard {
    static func groupedByLane(_ builds: [Build]) -> [String: [Build]] {
        Dictionary(grouping: builds, by: \.lane)
    }

    static func slowestBuildPerLane(_ builds: [Build]) -> [String: Build] {
        groupedByLane(builds).compactMapValues { laneBuilds in
            laneBuilds.max(by: { $0.durationSeconds < $1.durationSeconds })
        }
    }
}

@main
enum Demo {
    static func main() {
        let builds = [
            Build(branch: "feed-redesign", lane: "ios-ci", durationSeconds: 420),
            Build(branch: "paywall-abtest", lane: "ios-ci", durationSeconds: 315),
            Build(branch: "widget-cache", lane: "ui-tests", durationSeconds: 910),
            Build(branch: "checkout-copy", lane: "ui-tests", durationSeconds: 740)
        ]

        let summary = BuildDashboard.slowestBuildPerLane(builds)
        for lane in summary.keys.sorted() {
            if let build = summary[lane] {
                print("\(lane): \(build)")
            }
        }
    }
}
