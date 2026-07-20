// MARK: - From ObservableObject to @Observable
//
// # Swift Language Evolution: Observation Without Boilerplate
//
// I used to make every screen model conform to ObservableObject and mark every
// UI-driving property with @Published. That worked, but it duplicated intent:
// the type announced that it could change, then each property repeated that it
// could change. Swift's Observation framework makes the model itself observable
// and lets SwiftUI track exactly the fields a view reads.
//
// ## Legacy approach
//
// ```swift
// final class LegacyProfileModel: ObservableObject {
//     @Published var name = "Alex"
//     @Published var isSaving = false
// }
// ```
//
// The old pattern is still the right compatibility choice for an iOS 16
// deployment target or a Combine-based pipeline. On iOS 17+, I reach for
// @Observable when the state is owned by a view or feature.

import Observation

@Observable
final class ProfileEditorModel {
    var name: String
    private(set) var isSaving = false
    private(set) var lastSavedName: String?

    init(name: String) {
        self.name = name
    }

    func save() async throws {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false } // Every exit path restores UI state.

        try await Task.sleep(for: .milliseconds(150))
        lastSavedName = name
    }
}

// ## Modern SwiftUI boundary
//
// ```swift
// struct ProfileEditor: View {
//     @State private var model = ProfileEditorModel(name: "Alex")
//
//     var body: some View {
//         TextField("Name", text: $model.name)
//         Button("Save") { Task { try? await model.save() } }
//         if model.isSaving { ProgressView() }
//     }
// }
// ```
//
// ## Migration strategy
// 1. Keep ObservableObject at module boundaries shared with iOS 16 clients.
// 2. Convert one leaf feature at a time, creating it with @State in its owner.
// 3. Pass observable reference models directly; use @Bindable only where a
//    child needs a Binding such as $model.name.
// 4. Delete redundant @Published annotations after verifying view updates.
//
// ## Production notes
// I keep mutations on the main actor when they represent UI state, isolate
// network clients separately, and do not confuse @Observable with persistence
// or thread safety. Observation reduces invalidation work; it does not replace
// ownership, cancellation, or explicit error state.
