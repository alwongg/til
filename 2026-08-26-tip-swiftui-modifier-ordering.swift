// SwiftUI Tip: Make modifier ordering part of the component contract
//
// I treat modifier order as behavior, not decoration. A button's touch target,
// material, clipping, and accessibility frame should be obvious from its source.

import SwiftUI

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        // Put visual styling after sizing so the background covers the full target.
        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
        // Keep clipping after the background; reversing them can expose square fills.
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .foregroundStyle(.white)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityHint("Continues to the next step")
    }
}
