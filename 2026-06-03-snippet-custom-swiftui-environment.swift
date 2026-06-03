import SwiftUI

private struct AnalyticsContextKey: EnvironmentKey {
    static let defaultValue = AnalyticsContext(screen: "unknown", source: "organic")
}

extension EnvironmentValues {
    var analyticsContext: AnalyticsContext {
        get { self[AnalyticsContextKey.self] }
        set { self[AnalyticsContextKey.self] = newValue }
    }
}

struct AnalyticsContext: Sendable {
    let screen: String
    let source: String
}

struct CheckoutView: View {
    @Environment(\.analyticsContext) private var analyticsContext

    var body: some View {
        Button("Pay now") {
            // I prefer an environment value here because cross-cutting metadata
            // should flow from composition roots instead of leaking through every initializer.
            print("track checkout_tapped screen=\(analyticsContext.screen) source=\(analyticsContext.source)")
        }
    }
}

#Preview {
    CheckoutView()
        .environment(\.analyticsContext, AnalyticsContext(screen: "checkout", source: "campaign"))
}
