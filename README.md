# Split Tunnel for WireGuard

[![CI](https://github.com/netglance/wireguard-split-tunnel/actions/workflows/ci.yml/badge.svg)](https://github.com/netglance/wireguard-split-tunnel/actions/workflows/ci.yml)
[![Latest release](https://img.shields.io/github/v/release/netglance/wireguard-split-tunnel)](https://github.com/netglance/wireguard-split-tunnel/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Platform: macOS 15+](https://img.shields.io/badge/platform-macOS%2015%2B-lightgrey)
[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-support-FFDD00?logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/vpotar)

[Install](#install) · [Use](#use) · [How it works](#how-it-works) · [Privacy](#privacy) · [Limits](#limits) · [Contributing](#contributing) · [Security](#security) · [Support](#support) · [License](#license)

A macOS menu bar app that keeps chosen sites outside a WireGuard full tunnel. You add the sites that must bypass the VPN; the app resolves their IP addresses, recomputes the `AllowedIPs` line of your tunnel so those addresses are excluded, and warns you when a site gets a new IP or starts failing, so you know when to update the tunnel in WireGuard.

## Install

1. Download `SplitTunnel-<version>.zip` from [Releases](https://github.com/netglance/wireguard-split-tunnel/releases), unzip it and move `SplitTunnel.app` to Applications.
2. The app is not notarized, so macOS blocks the first launch. Open System Settings → Privacy & Security → "Open Anyway", or run:
   ```
   xattr -dr com.apple.quarantine /Applications/SplitTunnel.app
   ```

Requires macOS 15 or later.

## Use

1. Load your WireGuard config (drop the `.conf` file, or paste the text from WireGuard → Edit).
2. Add the sites that must bypass the VPN.
3. When the app asks, click "Update in WireGuard…" → copy the `AllowedIPs` line → in WireGuard select the tunnel, click Edit, replace the `AllowedIPs` line and Save.

The "Local network bypasses the VPN" switch (on by default) keeps your router, printers and other home devices out of the tunnel; turn it off to send them through it. Exclusions already present in your config's `AllowedIPs` are kept, and the tunnel's own `Address` and `DNS` always stay in the tunnel.

## How it works

WireGuard cannot exclude a domain from a full tunnel, only IP ranges. The app resolves the sites you add, subtracts their IP addresses and your local networks from the `AllowedIPs` of your config, and shows the resulting line to paste into WireGuard. It then checks that each site's traffic really bypasses the tunnel and that the site replies, and warns you when a site's IPs change.

## Privacy

The private key is never stored. The only network requests are DNS lookups and HTTPS checks of the sites you add, plus a daily check for a new version on GitHub.

## Limits

- Only the domains you add are excluded: images and CDN on other domains still go through the VPN. Add those domains too.
- One `[Peer]` per config.
- Any active `utun` VPN (for example a Tailscale exit node or a corporate VPN) is read as "tunnel on". Turn other VPNs off for accurate checks.

## Contributing

Contributions are welcome. Developers: see [CONTRIBUTING.md](CONTRIBUTING.md) for building, testing and the project rules.

## Security

To report a vulnerability, see [SECURITY.md](SECURITY.md).

## Support

If the app is useful, you can buy the author a coffee:

<a href="https://buymeacoffee.com/vpotar"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me a Coffee" height="48"></a>

## License

MIT — see [LICENSE](LICENSE).
