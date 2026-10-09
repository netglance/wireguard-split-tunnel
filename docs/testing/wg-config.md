# WGConfigTests

File: `Tests/SplitTunnelCoreTests/WGConfigTests.swift`. Run: `swift test --filter WGConfigTests`.

Covers `parseConfig` (reads the peer's `AllowedIPs` and `Endpoint`, and the interface `Address` and `DNS` that must stay in the tunnel), `replacingAllowedIPs` (rewrites only the `AllowedIPs` line) and `makeTunnelName`. The rewrite must leave the rest of the user's config untouched, because the saved `.conf` is imported back into WireGuard.

| Test | What it checks |
|---|---|
| `parsesSampleConfig` | The sample config parses into the expected `WGConfig`: `AllowedIPs`, endpoint, and `keepInTunnel` from `Address` and the IP `DNS` entries. |
| `keepInTunnelTakesOnlyInterfaceAddressAndIPDNS` | `keepInTunnel` takes only `[Interface]` `Address` and `DNS` entries that are IPs; junk, hostnames, CIDR ranges in `DNS` and `[Peer]` values are ignored. |
| `parsesCRLFTabsLowercaseCommentsAndRepeatedKeys` | CRLF line endings, tab separators, lowercase section and key names, trailing `#` comments and repeated `AllowedIPs` keys (merged) are handled; a bracketed IPv6 endpoint is kept. |
| `reportsWhatIsMissing` | Errors: `noPeer`, `multiplePeers`, `noAllowedIPs`, `noEndpoint`, and `badAddress` carrying the offending value. |
| `replacementKeepsEveryOtherLineByteForByte` | Replacing `AllowedIPs` changes only that line; the line count and every other line stay identical. |
| `replacementMergesRepeatedKeysAndKeepsCRLF` | Repeated `AllowedIPs` lines collapse into one, and CRLF endings are preserved. |
| `tunnelNameFromFileOrEndpoint` | The tunnel name is the file name without `.conf`, or the endpoint host (IPv6 brackets removed) when there is no file. |
| `sectionMustBeExactlyPeer` | `[PeerX]` and `[Peer]x` are not peer sections, `[Peer] # main` is, and `replacingAllowedIPs` leaves a `[PeerX]` section alone. |
| `commentedAndInterfaceAllowedIPsAreIgnored` | A commented-out `AllowedIPs` and one inside `[Interface]` are neither parsed nor rewritten. |
| `tunnelNameUsesLastPathComponentAndToleratesGarbage` | A full file path yields its last component; a malformed endpoint (`[`) does not crash. |

## Fixtures

- `sampleConfig` is modelled on a typical commercial VPN config. Both keys are fake base64 strings that decode to plain English text ("hello world this is not a real ke...", "example public key, not a real one..."), not real keys. Keep it that way: never put a real key or server address in a test or an issue.
- `10.14.0.2/16`, `162.252.172.57` and `149.154.159.92` are the sample's tunnel address and DNS servers; `vpn.example.com:51820` is its endpoint.
- Other tests build config text inline as strings, using `a:1` as a placeholder endpoint.
