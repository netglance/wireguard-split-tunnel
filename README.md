# Split Tunnel for WireGuard

[![CI](https://github.com/netglance/wireguard-split-tunnel/actions/workflows/ci.yml/badge.svg)](https://github.com/netglance/wireguard-split-tunnel/actions/workflows/ci.yml)
[![Latest release](https://img.shields.io/github/v/release/netglance/wireguard-split-tunnel)](https://github.com/netglance/wireguard-split-tunnel/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Platform: macOS 15+](https://img.shields.io/badge/platform-macOS%2015%2B-lightgrey)
[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-support-FFDD00?logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/vpotar)

[Install](#install) · [Use](#use) · [How it works](#how-it-works) · [Privacy](#privacy) · [Limits](#limits) · [Uninstall](#uninstall) · [Troubleshooting](#troubleshooting) · [Contributing](#contributing) · [Security](#security) · [Support](#support) · [License](#license)

A macOS menu bar app that keeps chosen sites outside a WireGuard full tunnel. You add the sites that must bypass the VPN; the app resolves their IP addresses, recomputes the `AllowedIPs` line of your tunnel so those addresses are excluded, and warns you when a site gets a new IP or starts failing, so you know when to update the tunnel in WireGuard.

## Install

1. Download `SplitTunnel-<version>.zip` from [Releases](https://github.com/netglance/wireguard-split-tunnel/releases), unzip it and move `SplitTunnel.app` to Applications.
2. The app is not notarized, so macOS blocks the first launch. Open System Settings → Privacy & Security → "Open Anyway", or run:
   ```
   xattr -dr com.apple.quarantine /Applications/SplitTunnel.app
   ```

Verify the download: run `shasum -a 256 SplitTunnel-<version>.zip` and compare the result with the `SplitTunnel-<version>.sha256` file attached to the release.

Requires macOS 15 or later.

## Use

1. Load your WireGuard config (drop the `.conf` file, or paste the text from WireGuard → Edit).
2. Add the sites that must bypass the VPN.
3. When the app asks, click "Update in WireGuard…" → copy the `AllowedIPs` line → in WireGuard select the tunnel, click Edit, replace the `AllowedIPs` line and Save.

Instead of copying the line, you can click "Save .conf…" in the same window. The app asks for your original `.conf` file, then where to save the new one: a copy of the original with only the `AllowedIPs` line replaced. The private key is read from the original, and the new file is written with mode 0600. Delete the old tunnel in WireGuard and import the new file; On-Demand rules have to be set up again.

The "Local network bypasses the VPN" switch (on by default) keeps your router, printers and other home devices out of the tunnel; turn it off to send them through it. Exclusions already present in your config's `AllowedIPs` are kept, and the tunnel's own `Address` and `DNS` always stay in the tunnel.

Other things to know:

- The app checks your sites every 30 minutes. To check right away, click the ↻ "Check Now" button in the menu bar panel (or "Check Now" in the main window).
- When you add the first site, macOS asks once for permission to show notifications. They tell you when a site gets a new IP or starts failing.
- To start the app when you log in, open the ⋯ menu in the panel and turn on "Open at Login".

## How it works

WireGuard cannot exclude a domain from a full tunnel, only IP ranges. The app resolves the sites you add, subtracts their IP addresses and your local networks from the `AllowedIPs` of your config, and shows the resulting line to paste into WireGuard. It then checks that each site's traffic really bypasses the tunnel and that the site replies, and warns you when a site's IPs change.

## Privacy

The app has no account, analytics or telemetry. It stores one file, `~/Library/Application Support/SplitTunnel/state.json`: the tunnel name, the server endpoint, the original `AllowedIPs`, your site list with the IP addresses and results of the last checks, and a few interface settings. The private key is never stored. "Save .conf…" reads it from the original file you pick, writes it only into the new file you choose (mode 0600), and keeps nothing.

The app makes three kinds of network requests, and nothing else:

- DNS lookups through the system resolver for your sites (and their `www.` variant), plus one for `apple.com` to tell a dead network from a mistyped site.
- One HTTPS GET to `https://<site>/` for each site, with a Safari User-Agent and a 10-second timeout. This runs every 30 minutes and when you click "Check Now".
- One unauthenticated GET to `https://api.github.com/repos/netglance/wireguard-split-tunnel/releases/latest` on launch and then about every 24 hours, to look for a new version. There is no setting to turn it off.

If `state.json` is unreadable, the app moves it aside as `state.json.<id>.broken` and keeps the newest three such files.

## Limits

- Only the domains you add are excluded: images and CDN on other domains still go through the VPN. Add those domains too.
- One `[Peer]` per config.
- Any active `utun` VPN (for example a Tailscale exit node or a corporate VPN) is read as "tunnel on". Turn other VPNs off for accurate checks.

## Uninstall

1. Turn off "Open at Login" in the ⋯ menu of the panel. If you already deleted the app, remove it in System Settings → General → Login Items instead.
2. Quit the app from the same menu.
3. Delete `/Applications/SplitTunnel.app`.
4. Delete the folder `~/Library/Application Support/SplitTunnel`.
5. Optional: remove "Split Tunnel" in System Settings → Notifications.

An `AllowedIPs` line you copied into WireGuard stays there. Restore your original line (or import your original `.conf` again) to send all traffic through the tunnel.

## Troubleshooting

- **"Open Anyway" is not shown in Privacy & Security.** Run `xattr -dr com.apple.quarantine /Applications/SplitTunnel.app` in Terminal, then open the app again.
- **Sites stay red or orange after you pasted the new `AllowedIPs`.** Turn the tunnel off and on in WireGuard so it picks up the new line, then click "Check Now".
- **The app says "Tunnel on" while WireGuard is off.** Another VPN that uses a `utun` interface (Tailscale, a corporate VPN) is active. Turn it off for accurate checks.
- **Why `4pda.to` in the examples?** It is a site that blocks many VPN exits, so it shows the problem well. Any site works.

## Contributing

Contributions are welcome. Developers: see [CONTRIBUTING.md](CONTRIBUTING.md) for building, testing and the project rules.

## Security

To report a vulnerability, see [SECURITY.md](SECURITY.md).

## Support

If the app is useful, you can buy the author a coffee:

<a href="https://buymeacoffee.com/vpotar"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me a Coffee" height="48"></a>

## License

MIT — see [LICENSE](LICENSE).

WireGuard is a registered trademark of Jason A. Donenfeld. This project is not affiliated with or endorsed by the WireGuard project.
