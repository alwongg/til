import Foundation

/*:
 # How I Evolve MVVM Into Feature-Sliced Architecture

 I still run into iOS features where MVVM started clean, then slowly turned into a storage layer, networking layer, navigation layer, and formatting layer all packed into one view model.

 The problem usually isn’t that MVVM is bad. It’s that the view model becomes the easiest place to put the next responsibility, so the boundary erodes one “quick” decision at a time.

 When I need the architecture to hold up longer, I split the feature into smaller roles: repository for data access, use case for the business rule, and a view model that only translates state for the UI.

 ## Legacy approach

 This is the shape I try to move away from:

 ```swift
 final class LegacyCheckoutViewModel: ObservableObject {
     @Published var summaryText = ""
     @Published var isLoading = false

     func loadCart(userID: String) {
         isLoading = true

         URLSession.shared.dataTask(with: URL(string: "https://example.com/cart/\(userID)")!) { data, _, _ in
             defer { DispatchQueue.main.async { self.isLoading = false } }

             guard
                 let data,
                 let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                 let total = json["total"] as? Double,
                 let itemCount = json["itemCount"] as? Int
             else {
                 DispatchQueue.main.async {
                     self.summaryText = "Cart unavailable"
                 }
                 return
             }

             if total > 100 {
                 DispatchQueue.main.async {
                     self.summaryText = "\(itemCount) items • Free shipping"
                 }
             } else {
                 DispatchQueue.main.async {
                     self.summaryText = "\(itemCount) items • Shipping applies"
                 }
             }
         }.resume()
     }
 }
 ```

 This works, but the view model now owns too many decisions:
 - building the request
 - decoding transport data
 - applying checkout rules
 - formatting UI state
 - deciding fallback behavior

 Once that pile grows, tests get awkward and future changes start colliding in one file.

 ## Modern approach

 I prefer to keep the feature flow explicit.

 ```swift
 struct Cart: Sendable {
     let itemCount: Int
     let total: Double
 }

 protocol CartRepository: Sendable {
     func fetchCart(for userID: String) async throws -> Cart
 }

 struct StubCartRepository: CartRepository {
     func fetchCart(for userID: String) async throws -> Cart {
         // In production this would call an API client.
         // The view model should not care where the cart came from.
         try await Task.sleep(for: .milliseconds(50))
         return Cart(itemCount: 3, total: userID == "vip" ? 140 : 72)
     }
 }

 struct CheckoutSummary: Sendable {
     let text: String
 }

 struct BuildCheckoutSummaryUseCase: Sendable {
     let repository: any CartRepository

     func execute(userID: String) async throws -> CheckoutSummary {
         let cart = try await repository.fetchCart(for: userID)

         let shippingText = if cart.total >= 100 {
             "Free shipping"
         } else {
             "Shipping applies"
         }

         return CheckoutSummary(
             text: "\(cart.itemCount) items • \(shippingText)"
         )
     }
 }

 @MainActor
 final class CheckoutViewModel {
     private let buildSummary: BuildCheckoutSummaryUseCase

     private(set) var summaryText = ""
     private(set) var isLoading = false

     init(buildSummary: BuildCheckoutSummaryUseCase) {
         self.buildSummary = buildSummary
     }

     func loadCart(userID: String) async {
         isLoading = true
         defer { isLoading = false }

         do {
             let summary = try await buildSummary.execute(userID: userID)
             summaryText = summary.text
         } catch {
             summaryText = "Cart unavailable"
         }
     }
 }

 @main
 enum Demo {
     static func main() async {
         let repository = StubCartRepository()
         let useCase = BuildCheckoutSummaryUseCase(repository: repository)
         let viewModel = CheckoutViewModel(buildSummary: useCase)

         await viewModel.loadCart(userID: "vip")
         print(viewModel.summaryText)
     }
 }
 ```

 What I like about this split:
 - the repository owns data access
 - the use case owns the business rule
 - the view model owns UI-facing state
 - each layer becomes easier to replace and test in isolation

 ## Migration strategy

 I usually do this transition in four small steps instead of one rewrite:

 1. Pull the data-fetching code behind a repository protocol without changing the screen behavior.
 2. Move one business rule into a use case, especially if it already has branching logic.
 3. Leave presentation formatting in the view model until the repository and use case boundaries feel stable.
 4. Once tests are easier to write, keep new responsibilities out of the view model on purpose.

 That path lets me improve the architecture without pausing feature delivery.

 ## Production notes

 - I don’t create a use case for every trivial getter. I add the layer when the rule actually carries meaning.
 - Feature slices help most when names map to real product behavior, not abstract patterns.
 - Repositories should hide transport details; otherwise the feature still leaks infrastructure upward.
 - A thinner view model usually means fewer accidental regressions when UI and backend work move in parallel.

 The architecture upgrade I want is rarely “more patterns.” It’s clearer ownership, so the next change has an obvious place to go.
 */
