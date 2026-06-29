import SwiftUI

/*
 PreferenceKey is the cleanest way I know to let a child view publish layout facts
 upward without turning the whole tree into a binding graph. I use it when the
 parent owns the reaction but the child is the only place that can measure itself.
 */

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct MeasuredSection<Content: View>: View {
    @Binding var contentHeight: CGFloat
    let content: Content

    init(contentHeight: Binding<CGFloat>, @ViewBuilder content: () -> Content) {
        _contentHeight = contentHeight
        self.content = content()
    }

    var body: some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: ContentHeightKey.self, value: proxy.size.height)
                }
            )
            .onPreferenceChange(ContentHeightKey.self) { contentHeight = $0 }
    }
}

struct CheckoutSummaryView: View {
    @State private var detailsHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MeasuredSection(contentHeight: $detailsHeight) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Order details")
                        .font(.headline)
                    Text("Shipping, taxes, and discounts can change this block's height.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Pin the CTA after \(Int(detailsHeight))pt of measured content.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
