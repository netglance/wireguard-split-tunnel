# AppStateTests

File: `Tests/SplitTunnelCoreTests/AppStateTests.swift`. Run: `swift test --filter AppStateTests`.

Covers `AppState`, the model behind the UI: the site list, resolved IPs (`seen`, `hasNewIPs`), export tracking (`needsUpdate`, `awaitingUpdate`, `pendingChanges`), applying check results (`apply`, which also decides when to notify), the "Local network bypasses the VPN" toggle, and loading and saving the state file. Mistakes here show up as missing or repeated notifications, a wrong "update the tunnel" prompt, or lost user data.

| Test | What it checks |
|---|---|
| `addSiteRejectsDuplicates` | Adding an existing domain returns false; a new one returns true; removing a site leaves the rest. |
| `mergeAccumulatesSeenWithoutDuplicates` | Resolved IPs accumulate across merges without duplicates; an empty result keeps what was seen; the site has new IPs and `pendingChanges` is 1. |
| `markExportedClearsNewIPsAndWaitsForTunnel` | After export the site has no new IPs, the state waits for the tunnel update (`awaitingUpdate`), and the computed `AllowedIPs` exclude the site IP. |
| `loadingAlreadySplitConfigMarksExcludedIPsExported` | Loading a config that already excludes the site IPs marks them exported; loading a full-tunnel config makes them new again. |
| `applyClearsAwaitingOnlyWhenAllSitesGoDirect` | `awaitingUpdate` stays while a site still goes through the tunnel and clears once it goes direct (`confirmedOnce` becomes true). |
| `notifiesOncePerProblemAndAgainAfterRecovery` | A problem notifies once, not on repeat checks, and again after a recovery; the first status of a site only seeds. |
| `doesNotNotifyOnFirstStatusOfANewSite` | The first status of a new site never notifies, but is stored (level bad). |
| `ipsOutsideOriginalAllowedIPsAreNeverNew` | Site IPs outside the config's `AllowedIPs` (IPv6 on an IPv4-only config, a local address) are never new, also after reloading; an IP inside it is. |
| `awaitingUpdateIgnoresSitesThatDoNotResolve` | A site that does not resolve does not block confirmation; if it is the only site, the state keeps waiting and `confirmedOnce` stays false. |
| `notifiesAboutNewIPButNotWhileTunnelIsOff` | New IPs notify only when the tunnel is up. |
| `applyIgnoresSitesRemovedDuringCheck` | A probe result for a site removed during the check is ignored. |
| `tunnelProbePrefersWellKnownPublicAddress` | The tunnel probe address is `1.1.1.1`, then `8.8.8.8` if a site uses it, and the first address of a narrow range (`100.64.0.1`) if the config has no well-known address. |
| `savesAndLoadsAndKeepsBrokenFile` | State round-trips through JSON; a corrupt file is moved aside as `.broken` and an empty state is returned that can be saved; a missing file gives an empty, saveable state. |
| `keepsOnlyThreeNewestBrokenFiles` | After five corrupt loads only three `.broken` files remain. |
| `oldFormatBrokenFilesDoNotPushOutTheNewlyMovedFile` | Old-format `.broken` names (uppercase UUIDs) do not displace the file just moved aside; pruning goes by modification date, not by name. |
| `cannotSaveWhenBrokenFileCannotBeMovedAside` | If the corrupt file cannot be moved (read-only directory), the state is empty and `canSave` is false, so the file is not overwritten. |
| `importedFullTunnelNeedsUpdateUntilExported` | A freshly imported full tunnel needs an update (local networks are not excluded yet); export clears it; with no sites nothing awaits confirmation; the toggle off and on again flips `needsUpdate`. |
| `removingAnExportedSiteNeedsUpdate` | Removing an exported site sets `needsUpdate` and one pending change until the next export. |
| `removingASiteNeverExportedDoesNotAsk` | Removing a site that was never exported, or whose IPs were new and unexported, does not ask for an update. |
| `loadingKeepsTheTunnelsOwnAddressAndDNSRouted` | `keepInTunnel` addresses stay in the computed `AllowedIPs`, and a site IP inside the tunnel's own subnet is never cut out, so never new. |
| `toggleOffMakesLocalIPsRoutedSoTheyCountAsNew` | With the toggle off, a site on a local address counts as new. |
| `configExclusionsShowManualHolesOnly` | `configExclusions` lists only the user's own holes, not local networks or site IPs. |
| `oldStateFileWithoutTheToggleFieldsStillDecodes` | A state file without `bypassLocal`, `keepInTunnel` and `exportedAllowedIPs` still decodes, with the toggle on and no update needed; the obsolete `removedSinceExport` key is ignored. |
| `reloadingAGeneratedConfigNeverMakesSiteIPsNew` | Parameterized by loop, 2 cases (toggle on with an address inside the tunnel subnet, toggle off with a local address): reloading the app's own generated config leaves no new IPs and no update needed. |
| `flippingTheToggleBackDoesNotLeaveLocalIPsNew` | Turning the toggle off makes a local site IP new; turning it back on clears that. |

## Fixtures

- `stateWith4pda()` loads a full-tunnel config (`0.0.0.0/0`, endpoint `pl-waw.prod.surfshark.com:51820`, file `pl.conf`) and adds `4pda.to`. Addresses such as `104.20.39.144` are public; `192.168.1.10` stands for a local device.
- `SiteProbe(domain:route:reply:)` is a hand-built check result; no network is used.
- The persistence tests write to a unique directory under the system temp folder and remove it afterwards. `cannotSaveWhenBrokenFileCannotBeMovedAside` sets the directory to mode `0o500`, then restores it so cleanup works.
