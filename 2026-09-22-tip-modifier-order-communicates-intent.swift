import SwiftUI

/// I treat modifier order as part of a view's API: each modifier receives the
/// result of the previous one, so changing the order changes the rendered tree.
struct ProfileCard: View {
    let name: String

    var body: some View {
        Text(name)
            .font(.headline)
            .foregroundStyle(.primary)
            .padding(16) // Adds space inside the card's background.
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.quaternary, lineWidth: 1)
            }
            .padding(.horizontal) // Adds space around the complete card.
            .accessibilityAddTraits(.isButton)
    }
}

@main
struct ModifierOrderDemo: App {
    var body: some Scene {
        WindowGroup {
            ProfileCard(name: "Alex")
        }
    }
}
