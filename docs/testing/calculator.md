# CalculatorTests

File: `Tests/SplitTunnelCoreTests/CalculatorTests.swift`. Run: `swift test --filter CalculatorTests`.

Covers `IPNet` (parsing, masking, containment, Codable) and `computeAllowedIPs`, which subtracts site IPs and local networks from the config's `AllowedIPs`. A wrong result here either leaks a site into the tunnel or cuts off traffic that must stay in it, so the exact output is pinned.

| Test | What it checks |
|---|---|
| `parsesAndMasksCIDR` | CIDR parsing masks host bits, a bare address becomes /32 or /128, whitespace is trimmed, and malformed input (`/33`, `/x`, `/+24`, `/-0`, empty prefix, hostname, empty string) is rejected. |
| `containsRespectsFamilyAndPrefix` | A network contains a narrower one inside it, not a wider one or one outside it, and never an address of the other IP family. |
| `codableRoundTrip` | `[IPNet]` encodes to the expected JSON strings and decodes back unchanged. |
| `excludes4pdaIPv4LikePythonReference` | Excluding the two 4pda IPv4 addresses from `0.0.0.0/0` yields exactly 90 networks, equal to the pinned reference string. |
| `excludes4pdaIPv6LikePythonReference` | Excluding the two 4pda IPv6 addresses from `::/0` yields 164 networks, from `::/3` to `fec0::/10`, with neighbours kept and the site addresses excluded. |
| `v4OnlyConfigStaysV4` | An IPv4-only config never gains IPv6 networks, even when an IPv6 address is excluded. |
| `excludingNothingKeepsOriginalMinusLocalNets` | With no sites, a config outside the local ranges is returned unchanged. |
| `fullIPv6ConfigNeverOverlapsLocalNetworks` | `::/0` minus nothing leaves no overlap with `fc00::/7`, `fe80::/10` or `ff00::/8`. |
| `toggleOffPutsLocalNetworksBackInTheTunnel` | With `bypassLocal: false` local addresses are routed again, site IPs stay excluded, and this holds even if the imported config had already excluded the local networks. |
| `configsOwnExclusionsSurviveInBothToggleStates` | Holes the user made in the config survive with the toggle on and off, while other addresses stay routed. |
| `keepInTunnelWinsOverSiteIPs` | Addresses in `keepInTunnel` (the tunnel's `Address` and `DNS`) stay routed even if a site resolves to them; other site IPs are still excluded. |
| `sameCoverageIgnoresHowTheSetIsSplit` | `sameCoverage` compares covered address space, not how it is split into networks. |

## Fixtures

- `expected4pdaV4` is the AllowedIPs line for `0.0.0.0/0` minus `104.20.39.144` and `172.66.159.63`, plus the local networks. It was generated once with Python's `ipaddress` module, so the Swift algorithm is compared with an independent implementation. The IPv6 test pins the count (164) and the first and last networks.
- The 4pda addresses are public; no private data is involved.
- The private helper `nets(...)` builds `[IPNet]` from strings; `ip(...)` builds one `IPNet`.

To regenerate the reference (Python 3, standard library only):

```python
from ipaddress import ip_network as n

def exclude(all_, excl):
    nets = [n(all_)]
    for e in map(n, excl):
        nets = [s for x in nets for s in (x.address_exclude(e) if e.subnet_of(x) else [x])]
    return sorted(nets)

print(", ".join(map(str, exclude("0.0.0.0/0", [
    "104.20.39.144/32", "172.66.159.63/32",
    "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "169.254.0.0/16", "224.0.0.0/4",
]))))
```
