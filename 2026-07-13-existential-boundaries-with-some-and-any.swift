import Foundation

/*
# Slot 1/4 — Swift Language Evolution
## Existential boundaries with `some` and `any`

I used to reach for protocol types everywhere because they felt flexible.
The problem was that I erased concrete behavior too early, then paid for it with weaker compiler guarantees and fuzzier APIs.
Modern Swift makes me be more honest: `some` when I want one hidden concrete type, `any` when I truly need heterogeneity.

## Legacy approach
I would expose protocol-typed values by default and let the caller figure out what capabilities were still available.
That made simple abstractions look elegant, but it hid whether the boundary preserved one concrete implementation or many interchangeable ones.

## Modern approach
I now treat `some` and `any` as two different architectural signals.
`some` tells callers there is one concrete type behind the curtain and the compiler can still optimize around that.
`any` tells callers I am intentionally accepting runtime polymorphism because storage or composition actually needs it.

## Migration strategy
1. Start by finding APIs that return protocol types even though they always construct one concrete type.
2. Change those return values to `some Protocol` and let the compiler show me where the abstraction becomes clearer.
3. Keep `any Protocol` only at storage boundaries like arrays, registries, or plug-in style composition.
4. If I need both flexibility and stable behavior, I move the existential boundary outward instead of erasing too early.

## Production notes
- `some` is great for factories and feature builders because it preserves intent without leaking implementation names.
- `any` is the right tradeoff when I need a mixed collection or truly dynamic replacement at runtime.
- When an API feels vague, the fix is often not more comments — it is choosing the right existential boundary.
*/

protocol LessonRenderable {
    var title: String { get }
    func render() -> String
}

struct TextLesson: LessonRenderable {
    let title: String
    let body: String

    func render() -> String {
        "📘 \(title): \(body)"
    }
}

struct VideoLesson: LessonRenderable {
    let title: String
    let durationMinutes: Int

    func render() -> String {
        "🎬 \(title) (\(durationMinutes)m)"
    }
}

enum LessonLibrary {
    static func featuredLesson() -> some LessonRenderable {
        TextLesson(
            title: "Opaque return types",
            body: "Use `some` when the factory always returns one concrete lesson shape."
        )
    }

    static func learningQueue() -> [any LessonRenderable] {
        [
            TextLesson(
                title: "Existentials",
                body: "Reach for `any` when storage genuinely needs multiple conforming types."
            ),
            VideoLesson(
                title: "Protocol boundaries",
                durationMinutes: 12
            )
        ]
    }
}

enum MigrationStep: String, CaseIterable {
    case replacePrematureErasure = "Replace protocol returns with `some` when the implementation is fixed"
    case keepRuntimePolymorphismAtStorage = "Keep `any` at arrays, registries, and plug-in boundaries"
    case pushErasureOutward = "Move existential boundaries outward so core flows stay strongly typed"
}

@main
enum LessonDemo {
    static func main() {
        let featured = LessonLibrary.featuredLesson()
        print(featured.render())

        for lesson in LessonLibrary.learningQueue() {
            print(lesson.render())
        }

        for step in MigrationStep.allCases {
            print("• \(step.rawValue)")
        }
    }
}
