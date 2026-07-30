# Make `xcodebuild` failures actionable with structured result bundles

I used to treat CI failures as a log-search problem: download the console text, hunt for `error:`, then hope the first match was the cause. That works until the build is running tests, multiple destinations, package resolution, and several schemes. At that point the log is an unreliable interface.

## Legacy approach: scrape the console

```sh
xcodebuild test \
  -scheme MyApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' | tee build.log

grep -n 'error:' build.log
```

This loses structure. A compiler error, a simulator boot warning, and a failed assertion all look like lines in the same stream. Piping also makes it easy to accidentally mask `xcodebuild`'s exit status.

## Modern approach: make the result bundle the artifact

```sh
set -o pipefail

RESULT_BUNDLE="$PWD/artifacts/MyApp.xcresult"
mkdir -p "$(dirname "$RESULT_BUNDLE")"
rm -rf "$RESULT_BUNDLE"

xcodebuild test \
  -scheme MyApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -resultBundlePath "$RESULT_BUNDLE" \
  | tee artifacts/xcodebuild.log
```

The `.xcresult` bundle preserves the test hierarchy, failures, attachments, and diagnostics. I can inspect it locally in Xcode and let CI keep the same bundle as a downloadable artifact. The console becomes a quick signal; the result bundle becomes the source of truth.

For a compact machine-readable summary, I export the result bundle instead of parsing prose:

```sh
xcrun xcresulttool get test-results summary \
  --path "$RESULT_BUNDLE" \
  --format json > artifacts/test-summary.json
```

I use this JSON for a CI annotation step that names the failed test and points engineers to the retained `.xcresult` bundle. I keep the raw log too: it is still useful for build-system failures that occur before test results exist.

## Migration strategy

1. Add `-resultBundlePath` to one test job without changing the existing log output.
2. Upload `*.xcresult`, the raw log, and any exported summary as CI artifacts, even on failure.
3. Teach the failure reporter to use the summary only when it exists; fall back to the console otherwise.
4. Standardize the artifact name by scheme and destination so re-runs do not overwrite each other.

## Production notes

- Remove a previous bundle before every run. `xcodebuild` refuses to write over an existing path.
- Use a unique path per parallel shard, such as `UnitTests-iPhone-16.xcresult`.
- Keep `set -o pipefail` whenever `xcodebuild` is piped through `tee`; otherwise a failing test run can appear successful.
- Retain result bundles for a shorter period than logs if storage matters, but long enough to diagnose flaky failures with screenshots or attachments.
- Treat simulator/device setup failures separately from assertion failures in CI messaging. The remediation and owner are different.

The payoff is small but compounding: failures arrive with their data model intact, so I spend less time reconstructing what Xcode already knew.