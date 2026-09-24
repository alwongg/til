# Xcode Test Plans: Turn One Scheme into a Release Gate

I used to duplicate schemes whenever a target needed a different test configuration: a fast local run, a deterministic CI run, and a release-candidate run. That worked until scheme drift made the configuration itself impossible to trust.

## Legacy approach: schemes as configuration copies

```text
App-Debug       → unit tests, default arguments
App-CI          → unit tests, mocked network
App-Release     → unit + UI tests, production-like flags
```

The problem was not the number of schemes. It was that test settings lived in several places: launch arguments, environment variables, selected tests, locales, and device choices. A new test target or argument was easy to add to one scheme and forget in the other two.

## Modern approach: schemes choose; test plans define

I keep one app scheme and put the test matrix in `.xctestplan` files. The scheme selects a plan; the plan owns test targets, configurations, repetitions, sanitizers, arguments, and environments.

```text
App scheme
 ├─ Local.xctestplan     fast feedback; no retries
 ├─ CI.xctestplan        deterministic services; repetitions on flaky suites
 └─ Release.xctestplan   unit + UI smoke path; production-like feature flags
```

For example, I make external dependencies explicit rather than relying on a developer's local defaults:

```json
{
  "environmentVariableEntries": [
    {
      "key": "API_BASE_URL",
      "value": "http://127.0.0.1:8080",
      "isEnabled": true
    },
    {
      "key": "FEATURE_PAYWALL_V2",
      "value": "0",
      "isEnabled": true
    }
  ]
}
```

The app reads these values through an injected configuration boundary. Tests then state the world they expect instead of quietly inheriting the world Xcode happened to launch with.

## Migration strategy

1. Pick the CI scheme first; it has the highest cost of drift.
2. Create `CI.xctestplan` from that scheme and commit the plan.
3. Move arguments, environment values, test targets, and retry settings into the plan.
4. Reduce the scheme to selecting that plan. Delete duplicated schemes only after CI has passed from the committed plan.
5. Add a minimal `Local.xctestplan` rather than weakening CI just to make iteration faster.

## Production notes

- Treat a test plan as source code: review its diff and keep it in version control.
- Use explicit feature-flag values in the release plan. An absent value is an accidental dependency on a default, not coverage.
- Keep repetitions targeted. Retrying every test hides flakes and slows the signal; repeat known timing-sensitive UI suites while fixing their root cause.
- Pin simulator runtime and destination in CI. A test plan controls behaviour, but the runner still needs a reproducible platform.
- When a failure only appears in CI, download the `.xcresult` and inspect attachments before increasing retries. Logs and screenshots usually distinguish an app bug from an infrastructure failure.

The payoff is simple: I can add a new release gate without cloning a scheme, and anyone can see the exact conditions under which the tests ran.
