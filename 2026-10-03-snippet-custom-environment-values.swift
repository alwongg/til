// Swift Snippet: Custom SwiftUI Environment Values
//
// I use a custom environment value when a presentation concern should flow
// through a feature tree without making every intermediate view accept a prop.

import SwiftUI

private struct CheckoutExperimentKey: EnvironmentKey {
    // A safe default keeps previews and older call sites working during rollout.
    static let defaultValue = false
}

extension EnvironmentValues {
    var isCheckoutExperimentEnabled: Bool {
        get { self[CheckoutExperimentKey.self] }
        set { self[CheckoutExperimentKey.self] = newValue }
    }
}

struct CheckoutBadge: View {
    @Environment(\.isCheckoutExperimentEnabled) private var isEnabled

    var body: some View {
        if isEnabled {
            Text("New checkout")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
        }
    }
}

struct CheckoutScreen: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("Checkout")
            CheckoutBadge()
        }
        // I set this at the feature boundary, not in each descendant view.
        .environment(\.isCheckoutExperimentEnabled, true)
    }
}
