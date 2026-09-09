# SwiftUI Modifier Ordering Is Behaviour, Not Styling

I treat a SwiftUI modifier chain as a pipeline, not a bag of decoration. Each modifier wraps the view produced before it, so moving one can change hit testing, layout, and which pixels receive a background.

This is especially easy to miss when a rounded card looks correct but the tappable area is still only the text.

```swift
import SwiftUI

struct PlanCard: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16) // Expand the label before defining its shape.
                .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain) // Keep the custom card appearance predictable.
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityLabel("Open \(title)")
    }
}
```

The ordering matters:

- `frame` then `padding` makes the entire padded row part of the label.
- `background(_:in:)` applies the rounded shape to that expanded label.
- `contentShape` makes the interactive region explicit instead of relying on an incidental visual boundary.

My production rule: put size and spacing modifiers before visual containment, then declare interaction separately. When I need to debug a chain, I temporarily add translucent backgrounds between modifiers; it makes the wrapper order visible immediately.
