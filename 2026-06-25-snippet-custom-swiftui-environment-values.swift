import SwiftUI

struct AnalyticsClient {
    var track: (String) -> Void
}

private struct AnalyticsClientKey: EnvironmentKey {
    static let defaultValue = AnalyticsClient { event in
        print("Tracked event: \(event)")
    }
}

extension EnvironmentValues {
    var analyticsClient: AnalyticsClient {
        get { self[AnalyticsClientKey.self] }
        set { self[AnalyticsClientKey.self] = newValue }
    }
}

extension View {
    func analyticsClient(_ client: AnalyticsClient) -> some View {
        environment(\.analyticsClient, client)
    }
}

struct CheckoutButton: View {
    @Environment(\.analyticsClient) private var analyticsClient

    var body: some View {
        Button("Buy now") {
            // I prefer injecting behavior through the environment when it should
            // flow naturally through the tree instead of becoming a long chain of params.
            analyticsClient.track("checkout_tapped")
        }
    }
}

@main
struct DemoApp: App {
    var body: some Scene {
        WindowGroup {
            CheckoutButton()
                .analyticsClient(
                    AnalyticsClient { event in
                        print("Custom analytics sink: \(event)")
                    }
                )
        }
    }
}
