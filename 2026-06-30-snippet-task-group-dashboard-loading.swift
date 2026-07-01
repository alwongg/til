// Swift Snippet — withTaskGroup for concurrent dashboard loading
// I reach for TaskGroup when a screen needs several independent async reads.
// The key win is structured fan-out/fan-in: child tasks stay scoped to the parent,
// and I collect results as they finish instead of serializing the whole load path.

import Foundation

enum DashboardSection: String, CaseIterable, Hashable, Sendable {
    case profile
    case notifications
    case recommendations
}

struct SectionPayload: Sendable {
    let section: DashboardSection
    let value: String
}

func fetch(_ section: DashboardSection) async throws -> SectionPayload {
    let delay: UInt64 = switch section {
    case .profile: 120_000_000
    case .notifications: 80_000_000
    case .recommendations: 160_000_000
    }

    try await Task.sleep(nanoseconds: delay)
    return SectionPayload(section: section, value: "\(section.rawValue.capitalized) ready")
}

func loadDashboard() async throws -> [DashboardSection: String] {
    try await withThrowingTaskGroup(of: SectionPayload.self) { group in
        for section in DashboardSection.allCases {
            group.addTask { try await fetch(section) }
        }

        var result: [DashboardSection: String] = [:]
        for try await payload in group {
            result[payload.section] = payload.value
        }
        return result
    }
}

@main
enum Demo {
    static func main() async throws {
        let dashboard = try await loadDashboard()
        print(dashboard[.profile] ?? "Missing profile")
    }
}
