# Architecture reflection: make state ownership boring

The most expensive iOS bugs I see are rarely caused by a missing `if`. They come from an unclear answer to one question: **who owns this state?**

## The legacy shape

In a feature built quickly, the view controller or SwiftUI view often owns everything:

- fetches from the network;
- transforms server models for presentation;
- decides when to retry;
- coordinates navigation;
- holds loading and error state.

It works until the same data is needed on another screen, a deep link enters halfway through the flow, or a background refresh races a user action. At that point, every new condition is a patch over an ownership problem.

## The modern shape

I draw a narrow boundary around each kind of state:

```text
View
  renders ViewState and sends intents
ViewModel
  owns screen state and translates intents
UseCase
  owns one piece of business behaviour
Repository
  owns data-source selection and caching policy
Coordinator
  owns navigation state
```

The key is not adding layers for their own sake. It is giving every mutation one obvious home. A `ViewModel` can say “refresh was requested”; a use case decides what refresh means; a repository decides whether that means memory, disk, or network.

## Migration strategy

I do not rewrite a feature into five abstractions at once.

1. **Name the current state.** List the mutable values and mark their real owner.
2. **Extract the first unstable dependency.** Usually this is networking behind a protocol, not the whole screen.
3. **Move business decisions out of the view layer.** Keep rendering decisions close to the view.
4. **Make inputs and outputs explicit.** An intent, a use case call, and a view state are easier to test than callbacks shared across a controller.
5. **Stop when the boundary pays for itself.** A tiny, static screen does not need a miniature enterprise framework.

## Production notes

- Treat loading, empty, content, and error as deliberate states—not a collection of unrelated booleans.
- Keep cache invalidation in the repository. If two screens implement it differently, users will eventually notice.
- Let coordinators own navigation so a screen can be exercised without presenting UI.
- Prefer one-way state flow for async work: intent → operation → new state. It makes cancellation and stale responses visible.
- Measure the result by change isolation: when an API response changes, how many files must change?

My rule of thumb: architecture is successful when the next engineer can find the owner of a behaviour before they need to understand the whole feature.
