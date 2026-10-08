# Split Tunnel for WireGuard

[![CI](https://github.com/netglance/wireguard-split-tunnel/actions/workflows/ci.yml/badge.svg)](https://github.com/netglance/wireguard-split-tunnel/actions/workflows/ci.yml)
[![Latest release](https://img.shields.io/github/v/release/netglance/wireguard-split-tunnel)](https://github.com/netglance/wireguard-split-tunnel/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Platform: macOS 15+](https://img.shields.io/badge/platform-macOS%2015%2B-lightgrey)

English | [Русский](#split-tunnel-для-wireguard)

[Install](#install) · [Use](#use) · [How it works](#how-it-works) · [Privacy](#privacy) · [Limits](#limits) · [Build](#build) · [Contributing](#contributing) · [Security](#security) · [Support](#support) · [License](#license)

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

## Build

```
swift test
scripts/make-app.sh <version>
```

The app and a zip are written to `dist/`.

## Contributing

Contributions are welcome; see [CONTRIBUTING.md](CONTRIBUTING.md).

## Security

To report a vulnerability, see [SECURITY.md](SECURITY.md).

## Support

If the app is useful, you can [buy the author a coffee](https://buymeacoffee.com/vpotar).

## License

MIT — see LICENSE.

---

# Split Tunnel для WireGuard

[English](#split-tunnel-for-wireguard) | Русский

[Установка](#установка) · [Использование](#использование) · [Как это работает](#как-это-работает) · [Конфиденциальность](#конфиденциальность) · [Ограничения](#ограничения) · [Сборка](#сборка) · [Участие](#участие) · [Безопасность](#безопасность) · [Поддержка](#поддержка) · [Лицензия](#лицензия)

Приложение в строке меню macOS, которое выводит выбранные сайты из полного туннеля WireGuard. Вы добавляете сайты, которые должны идти мимо VPN; программа находит их IP-адреса, пересчитывает строку `AllowedIPs` вашего туннеля так, чтобы эти адреса в него не попадали, и предупреждает, когда у сайта сменился IP или он перестал отвечать, чтобы вы знали, когда пора обновить туннель в WireGuard.

## Установка

1. Скачайте `SplitTunnel-<версия>.zip` из [Releases](https://github.com/netglance/wireguard-split-tunnel/releases), распакуйте и перенесите `SplitTunnel.app` в «Программы».
2. Приложение не нотаризовано, поэтому при первом запуске macOS его блокирует. Откройте Системные настройки → Конфиденциальность и безопасность → «Всё равно открыть» или выполните:
   ```
   xattr -dr com.apple.quarantine /Applications/SplitTunnel.app
   ```

Нужна macOS 15 или новее.

## Использование

1. Загрузите конфиг WireGuard (перетащите файл `.conf` или вставьте текст из WireGuard → «Изменить»).
2. Добавьте сайты, которые должны идти мимо VPN.
3. Когда программа попросит, нажмите «Обновить в WireGuard…» → скопируйте строку `AllowedIPs` → в WireGuard выберите туннель, нажмите «Изменить», замените строку `AllowedIPs` и сохраните.

Переключатель «Локальная сеть мимо VPN» (по умолчанию включён) оставляет роутер, принтеры и другие домашние устройства вне туннеля; выключите его, чтобы направить их в туннель. Исключения, которые уже есть в `AllowedIPs` вашего конфига, сохраняются, а `Address` и `DNS` самого туннеля всегда остаются в туннеле.

## Как это работает

WireGuard не умеет исключать домены из полного туннеля, только диапазоны IP-адресов. Приложение находит адреса добавленных вами сайтов, вычитает их и ваши локальные сети из `AllowedIPs` конфига и показывает готовую строку для вставки в WireGuard. Затем оно проверяет, что трафик к сайту действительно идёт мимо туннеля и что сайт отвечает, и предупреждает, когда у сайта меняются IP.

## Конфиденциальность

Приватный ключ не сохраняется. Единственные сетевые запросы: DNS-запросы и HTTPS-проверки добавленных вами сайтов, а также ежедневная проверка новой версии на GitHub.

## Ограничения

- Исключаются только добавленные вами домены: картинки и CDN на других доменах всё равно идут через VPN. Добавьте и эти домены.
- Один `[Peer]` в конфиге.
- Любой активный VPN на `utun` (например, exit node Tailscale или корпоративный VPN) считается включённым туннелем. Для точных проверок отключите другие VPN.

## Сборка

```
swift test
scripts/make-app.sh <версия>
```

Приложение и zip-архив появятся в `dist/`.

## Участие

Правки приветствуются; см. [CONTRIBUTING.md](CONTRIBUTING.md).

## Безопасность

О найденной уязвимости сообщайте по инструкции в [SECURITY.md](SECURITY.md).

## Поддержка

Если программа пригодилась, можно [угостить автора кофе](https://buymeacoffee.com/vpotar).

## Лицензия

MIT — см. LICENSE.
