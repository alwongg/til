import SwiftUI

private struct AnalyticsClientKey: EnvironmentKey {
    static let defaultValue = AnalyticsClient.noop
}

extension EnvironmentValues {
    var analytics: AnalyticsClient {
        get { self[AnalyticsClientKey.self] }
        set { self[AnalyticsClientKey.self] = newValue }
    }
}

struct AnalyticsClient {
    var track: @Sendable (_ event: String) -> Void

    static let noop = AnalyticsClient { _ in }
    static let console = AnalyticsClient { event in
        print("Tracked: \(event)")
    }
}

struct PurchaseButton: View {
    @Environment(\.analytics) private var analytics

    var body: some View {
        Button("Buy") {
            analytics.track("purchase_tapped")
        }
    }
}

struct ContentView: View {
    var body: some View {
        PurchaseButton()
            .environment(\.analytics, .console)
    }
}
