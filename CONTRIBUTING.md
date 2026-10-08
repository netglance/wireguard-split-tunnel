# Contributing

Bug reports, ideas and pull requests are welcome. By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md). For security issues, see [SECURITY.md](SECURITY.md) instead of opening a public issue.

## Prerequisites

macOS 15 or later and Xcode 16 or later (Swift 6 toolchain).

## Build, test, run

```
swift test                  # run the tests
swift run SplitTunnel       # run for development
scripts/make-app.sh 0.1.0   # build dist/SplitTunnel.app and a zip (universal, ad-hoc signed)
```

Test documentation: [docs/testing/README.md](docs/testing/README.md).

Notifications need the bundled app, so they do not work under `swift run`; use `scripts/make-app.sh` and open `dist/SplitTunnel.app` to test them.

## Project layout

- `Sources/SplitTunnelCore`: pure logic (config parsing, `AllowedIPs` calculation, state, status). Fully unit-tested.
- `Sources/SplitTunnel`: the SwiftUI menu bar app (UI, networking, notifications).
- `Tests/SplitTunnelCoreTests`: tests for the core.
- `Resources`: `Info.plist`, icon and localizations.

## Rules

- Changes to `SplitTunnelCore` come with tests.
- No third-party dependencies.
- Keep pull requests small and focused; describe what and why.

## Localization

English string literals are the keys. Russian translations live in `Resources/ru.lproj/Localizable.strings`; add every new UI string there.

Never pass a ternary of string literals to `Text` or `Button`: the ternary is typed as `String`, so the text is not localized. Use two views, or `String(localized:)` on each branch.

### Adding a language

1. Create `Resources/<lang>.lproj/Localizable.strings` with a translation for every key in `ru.lproj`.
2. Add `<lang>` to `CFBundleLocalizations` in `Resources/Info.plist`.
3. Run `scripts/make-app.sh` and check the UI with that language selected.
