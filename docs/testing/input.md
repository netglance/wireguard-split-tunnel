# InputTests

File: `Tests/SplitTunnelCoreTests/InputTests.swift`. Run: `swift test --filter InputTests`.

Covers `normalizeDomain` (turns whatever the user types or pastes into a bare lowercase host), `lookupHosts` (hosts to resolve for a site) and `isNewer` (version comparison for the daily update check). Bad input here would add junk sites or hide a new release.

| Test | What it checks |
|---|---|
| `normalizesSiteInput` | Parameterized, 8 cases: a bare host; trimmed and lowercased input; a full URL with path and query reduced to the host; user info and port stripped; `www.` kept; a trailing dot removed; an internationalized (Cyrillic) host with a path; a URL with percent-encoded characters in path and query. |
| `rejectsNonDomains` | Parameterized, 14 cases that return `nil`: empty and blank strings, `localhost`, IPv4 literals (bare and in a URL), a host with a space, a bare `.com`, a bare scheme, empty labels (`a..b`, `x..`, `.a`, `a.b..`), and percent-encoded `/` or NUL in the host. |
| `addsWwwVariant` | A bare domain is looked up with its `www.` variant; a `www.` host is looked up alone. |
| `comparesVersions` | `isNewer` handles a `v` prefix, numeric (not string) comparison of `1.10` and `1.9`, and missing components (`1.2` equals `1.2.0`). |
| `comparesPreReleaseVersions` | A release is newer than its own pre-release, never the reverse; pre-release tags compare in order; a pre-release of a higher version is newer than an older release; `1.2.0-rc.1` is not newer than `1.2.0`. |

## Fixtures

- `4pda.to` is the example site used throughout the project.
- All inputs are inline strings; there are no files.
