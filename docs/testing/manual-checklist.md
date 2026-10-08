# Manual checklist

Run this end-to-end pass on a built app (`scripts/make-app.sh`, open `dist/SplitTunnel.app`) before every release. The unit tests do not cover the UI, notifications, the menu bar or the real tunnel.

Use a test WireGuard tunnel. Never paste real private keys or server addresses into issues or pull requests.

1. **First launch.** The window opens on first launch, a shield icon is in the menu bar, and there is no Dock icon.
2. **Load a config.** Drop a WireGuard `.conf` file. The tunnel name, server and range counts are shown.
3. **Add a site.** Add `https://4pda.to/forum/`. A row with its IPs appears, and the notification permission is requested once.
4. **Update in WireGuard.** Click Update in WireGuard, then Copy AllowedIPs. In WireGuard open Edit, replace the `AllowedIPs` line, Save, and turn the tunnel on. Click Check Now. The panel turns green with no dot, the coffee note appears once, and "Hide forever" is still in effect after relaunch.
5. **Tunnel off.** Turn the tunnel off. A grey banner appears and no notifications are sent.
6. **Unknown site.** Add `no-such-site-1234.example`. It shows a red "not found", and the panel does not say "No network".
7. **Save .conf.** Save .conf with a different config: an error is shown. Save with the matching config: the file is saved with mode `-rw-------` (check with `ls -l`).
8. **Open at Login.** The toggle switches on and off, and after reopening the panel shows the current state.
9. **Remove a site.** A confirmation dialog appears. After confirming, removing an exported site shows "AllowedIPs in WireGuard are out of date".
10. **Local network toggle.** Turn "Local network bypasses the VPN" off and on. The update badge appears and then disappears.
11. **Languages.** Check every screen in each supported language, launching with `open dist/SplitTunnel.app --args -AppleLanguages '(<lang>)'`. Nothing is clipped.
