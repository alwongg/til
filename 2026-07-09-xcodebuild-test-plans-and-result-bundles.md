# Xcodebuild test plans and result bundles

I used to treat CI failures like a scavenger hunt: rerun the scheme, scroll the raw log, and hope the failing test left enough clues. That works on a small app, but it breaks down once unit tests, UI tests, feature flags, and simulator differences all pile into the same lane.

## Legacy approach
- One long `xcodebuild test` command in CI.
- The scheme quietly owns too many decisions.
- Test selection, retries, and environment setup live in shell glue.
- When a run flakes, I get a red job but weak evidence.

## Modern approach
I now separate the workflow into three pieces:

1. **Scheme** for shared build configuration.
2. **`.xctestplan`** for lane-specific intent: which suites run, what environment they need, and which diagnostics should be enabled.
3. **`.xcresult` bundle** for the evidence I inspect after the run.

```bash
xcodebuild \
  -scheme ShopApp \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -testPlan PR \
  -resultBundlePath BuildArtifacts/PR.xcresult \
  test
```

That one shift changes the conversation from “why did CI behave differently?” to “which plan ran, and what did the result bundle capture?”

## Migration strategy
1. Start with the current green lane and move test selection into a named test plan like `PR`.
2. Create a second plan such as `Nightly` for slower suites, extra diagnostics, or broader device coverage.
3. Archive the result bundle as a first-class artifact.
4. Inspect failures with tooling instead of only reading terminal logs:

```bash
xcrun xcresulttool get \
  --path BuildArtifacts/PR.xcresult \
  --format json
```

## Production notes
- Keep the simulator destination explicit so local and CI runs match.
- Put retries and diagnostics in the test plan, not in ad hoc bash wrappers.
- Treat `.xcresult` as the source of truth for screenshots, failures, and performance metrics.
- If a lane starts flaking, compare two result bundles before touching app code. I usually learn faster from artifacts than from another rerun.

The practical transformation is simple: move **intent** into test plans and move **evidence** into result bundles. Once I do that, Xcode's tooling becomes much easier to reason about under pressure.
