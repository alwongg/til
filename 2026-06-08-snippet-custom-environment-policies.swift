import SwiftUI

// I use environment values for cross-cutting UI policy so previews and tests
// can override behavior without threading config through every initializer.
private struct RetryLimitKey: EnvironmentKey {
    static let defaultValue = 2
}

extension EnvironmentValues {
    var retryLimit: Int {
        get { self[RetryLimitKey.self] }
        set { self[RetryLimitKey.self] = newValue }
    }
}

extension View {
    func retryLimit(_ value: Int) -> some View {
        environment(\.retryLimit, value)
    }
}

struct SyncButton: View {
    @Environment(\.retryLimit) private var retryLimit
    let sync: () async throws -> Void

    var body: some View {
        Button("Sync now") {
            Task {
                for attempt in 0...retryLimit {
                    do {
                        try await sync()
                        return
                    } catch where attempt < retryLimit {
                        continue // Retry policy lives above the feature, not inside the view model.
                    } catch {
                        assertionFailure("Sync failed after \(retryLimit + 1) attempts: \(error)")
                    }
                }
            }
        }
    }
}

#Preview {
    SyncButton(sync: { })
        .retryLimit(0)
        .padding()
}
