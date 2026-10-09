# Changelog

All notable changes to this project are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- The copyright now shows in Finder's Get Info (the app has no About window).
- VoiceOver reads each site row in the menu bar panel as one item (site and status).
- App category (Utilities) in the bundle.
- Release workflow: pushing a `v*` tag builds the universal app, attaches the zip and its `.sha256` to a GitHub release, and uses the changelog section as notes.
- CI builds the app bundle and uploads it as an artifact.
- README: usage details, privacy, uninstall and troubleshooting sections, checksum verification and a trademark notice.

### Changed

- `make-app.sh` requires a version (`x.y.z` or `x.y.z-suffix`); the build number (`CFBundleVersion`) is the `x.y.z` part, and the signature is verified after signing.
- The update check no longer caches the GitHub response on disk.
- Release workflow hardening: read-only token for the build, a separate publishing job that runs only on a tag push, the tests run before the build, a tag without a CHANGELOG section is refused, and versions with a suffix (such as `-rc.1`) become pre-releases.
- Bug report form asks how the app was installed, the WireGuard app version and whether another VPN is active.

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
- English and Russian UI.
- Daily check for a new version.

[Unreleased]: https://github.com/netglance/wireguard-split-tunnel/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/netglance/wireguard-split-tunnel/releases/tag/v0.1.0
