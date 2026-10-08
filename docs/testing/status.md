# StatusTests

File: `Tests/SplitTunnelCoreTests/StatusTests.swift`. Run: `swift test --filter StatusTests`.

Covers how a site check becomes a status: `classify` (HTTP reply to `Reply`), `parseRouteInterface` and `aggregateRoute` (where traffic goes) and `SiteStatus.level` (what the panel shows). These decide the green, yellow, grey and red states and when the user is warned.

| Test | What it checks |
|---|---|
| `levelFollowsSpecMatrix` | The route and reply to level matrix: direct and ok is good; tunnel and ok is warn; tunnel off and ok is idle; new IPs make good or idle into warn; any failing reply (rate limited, forbidden, captcha, no response, not found) is bad on every route; levels order as `bad > warn > idle > good`. |
| `classifiesHTTPReplies` | 2xx, 3xx and 404 are ok (the server answered); 429 is rate limited; 403 is forbidden, or captcha when `cf-mitigated` is `challenge`; 503 is no response. |
| `parsesRouteOutput` | The interface is read from real `route get` output (`en0`); the "not in table" message and an empty `interface:` give `nil`. |
| `aggregatesRoutes` | Per-address interfaces combine into one route: all `en0` is direct; any `utun` is tunnel while the tunnel is up; `utun` with the tunnel down is tunnel off; no usable interface is unknown; an unresolved (`nil`) entry is ignored when another address shows a tunnel, but makes the result unknown beside a direct one; a `none` entry beside `en0` still gives direct. |

## Fixtures

- The `route get` text is a sample of macOS `route get` output for `104.20.39.144`, with the local gateway `192.168.50.1`; no private data.
- `utun4` stands for the WireGuard interface and `en0` for the physical one.
