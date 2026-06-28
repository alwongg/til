# Reflection & Architecture Thinking — Designing Seams Before Screens

On Sundays I like to zoom out and ask a simple question: **where should change land?**

A lot of iOS architecture pain starts when I design the UI first and only later discover that my boundaries are wrong. The view becomes the integration point for networking, formatting, analytics, feature flags, and navigation. It works for a sprint, then every small change drags across five files and three teams.

## Legacy approach

I used to start with the screen:

- build the SwiftUI view
- wire actions directly to services
- add conditionals for loading, errors, permissions, experiments, and navigation
- move fast until the feature becomes hard to reason about

That approach feels productive because pixels show up quickly. The cost appears later:

- testing becomes UI-heavy instead of logic-heavy
- async work leaks into presentation concerns
- analytics and side effects get scattered across button handlers
- a single product change forces edits everywhere

## Modern approach

Now I try to design **seams before screens**.

The architecture question I ask first is:

> Which parts of this feature change for different reasons?

That usually gives me a much healthier split:

- **View** renders state and forwards intent
- **ViewModel** coordinates state transitions
- **UseCase** expresses business intent in app language
- **Repository / Client** talks to data sources
- **Policy objects** hold decisions that vary independently

The important shift is that I’m not chasing purity. I’m trying to make change cheaper.

A good seam has three properties:

1. **It hides volatility** — API shape, storage details, experiment wiring
2. **It is easy to fake in tests** — protocol, closure, or value-based dependency
3. **It maps to a real ownership boundary** — not just an academic layer

## Migration strategy

When I’m cleaning up an existing feature, I don’t rewrite it wholesale.

I usually migrate in this order:

1. identify the noisiest reason the feature changes
2. extract that logic behind one boundary
3. make the UI depend on a stable interface
4. move side effects out of tap handlers
5. add tests at the new seam before extracting the next one

Examples:

- If API churn is hurting, extract a repository first
- If branching rules are hurting, extract policy/strategy objects first
- If navigation is tangled, isolate a coordinator or route model first
- If screen state is messy, introduce a clearer state machine in the ViewModel first

## Production notes

A few heuristics have held up well for me:

- If a ViewModel needs more and more booleans, I probably need a better state model
- If a feature flag check appears in multiple layers, I need one policy boundary
- If a test needs network stubs just to verify button behavior, my seam is too low-level
- If two modules change together every sprint, the boundary between them is probably fake
- If a dependency is hard to replace in previews, it will be annoying in tests too

## What I want to remember

Architecture is less about picking MVVM, TCA, Clean, or Coordinators as an identity.

It’s more about placing boundaries where change, failure, and ownership naturally collect.

When I get that right, the codebase feels calmer:

- features are easier to ship
- bugs are easier to localize
- tests are cheaper to write
- refactors stop feeling like demolition

That’s the Sunday reminder I keep coming back to: **design the seams first, then let the screens sit on top of them.**
