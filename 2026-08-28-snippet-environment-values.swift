import SwiftUI

private struct DiagnosticsEnabledKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var diagnosticsEnabled: Bool {
        get { self[DiagnosticsEnabledKey.self] }
        set { self[DiagnosticsEnabledKey.self] = newValue }
    }
}

struct SyncStatusView: View {
    @Environment(\.diagnosticsEnabled) private var diagnosticsEnabled

    var body: some View {
        VStack(spacing: 8) {
            Label("Synced", systemImage: "checkmark.icloud")
            if diagnosticsEnabled {
                // Keep debug-only UI opt-in so production screens stay focused.
                Text("Last sync: just now")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

@main
struct EnvironmentValueDemo: App {
    var body: some Scene {
        WindowGroup {
            SyncStatusView()
                .environment(\.diagnosticsEnabled, true)
        }
    }
}
