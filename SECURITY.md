# Security Policy

## Supported versions

Only the latest [release](https://github.com/netglance/wireguard-split-tunnel/releases) receives security fixes.

## Reporting a vulnerability

Please do not open a public issue. Use GitHub's private reporting instead:
[Report a vulnerability](https://github.com/netglance/wireguard-split-tunnel/security/advisories/new).

You can expect a first response within 7 days.

## Scope

In scope:

- handling of the WireGuard config and its private key;
- `AllowedIPs` computation that could send traffic or DNS outside the tunnel, or into it, against what the user configured;
- the state file.

## What the app does

The app never stores the private key. It makes no network requests except DNS lookups, HTTPS checks of the sites you add, and a check for a new release on GitHub. HTTPS checks follow redirects.
