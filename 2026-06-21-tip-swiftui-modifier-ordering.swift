import SwiftUI

/// I keep re-learning this: SwiftUI modifiers are a pipeline, not a bag of styles.
/// Once a modifier changes layout, every modifier after it works on a different shape.
struct ModifierOrderingTip: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Background before padding")
                .font(.headline)
                .foregroundStyle(.white)
                // Applying the background too early paints only the text's intrinsic size.
                .background(.red.opacity(0.85), in: Capsule())
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            Text("Padding before background")
                .primaryCapsule()
        }
        .padding()
    }
}

private extension View {
    func primaryCapsule() -> some View {
        self
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            // Padding first means the capsule wraps the final visual size I actually want.
            .background(.red.opacity(0.85), in: Capsule())
            // Matching the content shape keeps the whole capsule tappable in buttons and rows.
            .contentShape(Capsule())
    }
}
