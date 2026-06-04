import SwiftUI

private struct HeaderHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct CollapsingHeaderScreen: View {
    @State private var headerHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: 12) {
            Text("Header height: \(Int(headerHeight))")
                .font(.caption.monospacedDigit())

            Text("Featured Story")
                .font(.largeTitle.bold())
                .padding()
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: HeaderHeightKey.self, value: proxy.size.height)
                    }
                )
        }
        .onPreferenceChange(HeaderHeightKey.self) { newValue in
            // I use PreferenceKey when child layout data needs to flow upward
            // without turning the view tree into a maze of bindings.
            headerHeight = newValue
        }
    }
}

#Preview {
    CollapsingHeaderScreen()
}
