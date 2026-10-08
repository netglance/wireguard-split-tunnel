# Contributing

Bug reports, ideas and pull requests are welcome. By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md). For security issues, see [SECURITY.md](SECURITY.md) instead of opening a public issue.

## Prerequisites

macOS 15 or later and Xcode 16 or later (Swift 6 toolchain).

## Build, test, run

```
swift test                  # run the tests
swift run SplitTunnel       # run for development
scripts/make-app.sh 0.0.0-dev   # build dist/SplitTunnel.app and a zip (universal, ad-hoc signed)
```

The version comes only from the `make-app.sh` argument and must be `x.y.z` or `x.y.z-suffix`. It replaces `__VERSION__` in `Resources/Info.plist` (`CFBundleShortVersionString`); `CFBundleVersion` gets only the numeric `x.y.z` part (`__BUILD__`). `swift run` shows "dev".

Test documentation: [docs/testing/README.md](docs/testing/README.md).

Notifications need the bundled app, so they do not work under `swift run`; use `scripts/make-app.sh 0.0.0-dev` and open `dist/SplitTunnel.app` to test them.

## Project layout

- `Sources/SplitTunnelCore`: pure logic (config parsing, `AllowedIPs` calculation, state, status). Fully unit-tested.
- `Sources/SplitTunnel`: the SwiftUI menu bar app (UI, networking, notifications).
- `Tests/SplitTunnelCoreTests`: tests for the core.
- `Resources`: `Info.plist`, icon and localizations.
- `scripts`: `make-app.sh` (builds the app bundle and zip) and `make-icon.swift` (renders the icon; run from the repository root).
- `docs/testing`: test documentation and the manual checklist.

## Rules

- Changes to `SplitTunnelCore` come with tests.
- No third-party dependencies.
- Keep pull requests small and focused; describe what and why.
- Comments starting with `ponytail:` mark deliberate simplifications and name their limit and upgrade path.

## Localization

English string literals are the keys. Russian translations live in `Resources/ru.lproj/Localizable.strings`; add every new UI string there.

Never pass a ternary of string literals to `Text` or `Button`: the ternary is typed as `String`, so the text is not localized. Use two views, or `String(localized:)` on each branch.

### Adding a language

1. Create `Resources/<lang>.lproj/Localizable.strings` with a translation for every key in `ru.lproj`.
2. Add `<lang>` to `CFBundleLocalizations` in `Resources/Info.plist`.
3. Run `scripts/make-app.sh 0.0.0-dev` and check the UI with that language selected.

## Releasing

Run the manual checks in [docs/testing/manual-checklist.md](docs/testing/manual-checklist.md) first.

1. Move the items from `[Unreleased]` in `CHANGELOG.md` to a new `## [x.y.z] - YYYY-MM-DD` section, and update the compare links at the bottom.
2. Open a pull request and merge it.
3. Update your local `main`: `git switch main && git pull`.
4. Tag it: `git tag -a vX.Y.Z -m "Split Tunnel X.Y.Z"`.
5. Push the tag: `git push origin vX.Y.Z`.
6. The Release workflow runs the tests, builds the universal zip on `macos-15`, attaches it with a `.sha256` file, and uses the CHANGELOG section as the release notes. It refuses a tag without a CHANGELOG section for that version. A version with a suffix (for example `v0.2.0-rc.1`) becomes a pre-release.
7. Check that the workflow run succeeded and the release looks right.
8. The in-app update check sees the new release within 24 hours.

To rehearse without publishing, run the workflow by hand (Actions → Release → Run workflow). It builds the app and uploads an artifact only; no release is created.
