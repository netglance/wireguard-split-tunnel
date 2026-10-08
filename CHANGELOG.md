# Changelog

All notable changes to this project are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Copyright line in About and Get Info.
- VoiceOver labels on status indicators.

### Changed

- `make-app.sh` requires a version argument.

## [0.1.0] - 2026-10-08

### Added

- Menu bar app that keeps chosen sites outside a WireGuard full tunnel.
- Recomputation of the tunnel's `AllowedIPs` line so the resolved IPs of those sites are excluded.
- Route and HTTP checks of each site, with captcha detection.
- Notifications when a site's IP addresses change.
- Copy the `AllowedIPs` line, or save a `.conf` file; the private key is never stored and the file is written with mode 0600.
- "Local network bypasses the VPN" toggle.
- Exclusions already present in the config's `AllowedIPs` are preserved and shown.
- The tunnel's own `Address` and `DNS` always stay in the tunnel.
- Daily check for a new version.

[Unreleased]: https://github.com/netglance/wireguard-split-tunnel/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/netglance/wireguard-split-tunnel/releases/tag/v0.1.0
