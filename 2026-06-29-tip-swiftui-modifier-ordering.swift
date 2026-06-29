import SwiftUI

// I treat modifier order as part of the component contract.
// Padding before background expands the painted area.
// Padding after background expands only the hit/test layout around it.
struct ModifierOrderingTip: View {
    var body: some View {
        VStack(spacing: 24) {
            labeled("Background wraps the padding") {
                Text("Primary")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.blue)
                    .clipShape(Capsule())
            }

            labeled("Padding happens outside the background") {
                Text("Primary")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .background(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .clipShape(Capsule())
            }
        }
        .padding()
    }

    @ViewBuilder
    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            content()
                .overlay(Capsule().stroke(.red.opacity(0.35), style: .init(lineWidth: 1, dash: [4])))
        }
    }
}
