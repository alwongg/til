import SwiftUI

// I still double-check modifier order whenever a view looks visually "off".
// In SwiftUI, each modifier wraps the previous view, so order changes layout and rendering.
struct ModifierOrderingTipView: View {
    var body: some View {
        VStack(spacing: 24) {
            Text("Wrong mental model")
                .padding(12)
                .background(.blue)
                .cornerRadius(12)

            Text("Desired bubble")
                .background(.blue)
                .padding(12)
                .background(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundStyle(.white)
        }
        .font(.headline)
    }
}

#Preview {
    ModifierOrderingTipView()
}

// My rule of thumb:
// - size first (`frame`, `padding`)
// - paint next (`background`, `overlay`)
// - shape last (`clipShape`, `mask`)
// When I keep that order in my head, SwiftUI styling gets much more predictable.
