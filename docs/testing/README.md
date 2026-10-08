# Testing

The tests cover `SplitTunnelCore`, the pure logic behind the app: config parsing, `AllowedIPs` calculation, input normalization, status classification and app state. They are written with Swift Testing and live in `Tests/SplitTunnelCoreTests/`. The SwiftUI app, networking and notifications are not unit-tested; they are covered by the [manual checklist](manual-checklist.md).

## Run

```
swift test                              # all tests
swift test --filter CalculatorTests     # one suite
```

## CI

`.github/workflows/ci.yml` runs `swift build` and `swift test` on `macos-15` for every push to `main` and every pull request.

## Rule

Changes to `SplitTunnelCore` come with tests (see [CONTRIBUTING.md](../../CONTRIBUTING.md)).

## Contents

- [calculator.md](calculator.md): `IPNet` parsing and the `AllowedIPs` calculation, checked against a Python `ipaddress` reference.
- [wg-config.md](wg-config.md): parsing a WireGuard config, rewriting its `AllowedIPs` line, naming the tunnel.
- [input.md](input.md): site-input normalization, the `www` lookup variant and version comparison.
- [status.md](status.md): per-site status levels, HTTP reply classification and route parsing.
- [app-state.md](app-state.md): the app state machine, notifications, update tracking and state-file persistence.
- [manual-checklist.md](manual-checklist.md): the manual end-to-end pass before a release.
