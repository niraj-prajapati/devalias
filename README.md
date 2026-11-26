# DevAlias

[![CI](https://github.com/niraj-prajapati/devalias/actions/workflows/ci.yml/badge.svg)](https://github.com/niraj-prajapati/devalias/actions/workflows/ci.yml)

Ultra-lightweight **macOS Menu Bar** companion for mobile-testing local web/API servers.

Point your phone at the hub (`mac.local` or LAN IP), tap a discovered Vite/Next/Flutter port, ship.

**Status:** v0.1.x — GitHub Release zip (ad-hoc) or build from source. Prefer [notarized builds](RELEASE.md) when Developer ID is available.

## Features

- Menu Bar hub on a high port (default `49200`) + optional **Port 80** `pf` redirect
- Temporary mDNS `<alias>.local` while the hub runs
- Smart discovery (filters AirPlay / IDE / agent noise)
- Terminal-style phone dashboard + QR (`.local` first, toggle to **LAN IP** if the phone fails)
- Launch at Login + wake/network recovery
- Settings: ignores, Port 80, troubleshooting copy

## Requirements

- macOS 13+
- Same Wi‑Fi as your phone (not guest / AP-isolated)
- **Release zip:** nothing else — unzip and run the `.app`
- **From source:** Xcode / CLT + [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Install (GitHub Release)

1. Open **Releases** → download `DevAlias.zip` (and optionally verify `DevAlias.zip.sha256`).
2. Unzip → drag **`DevAlias.app`** to `/Applications` (or run from Downloads).
3. First open (ad-hoc / unsigned CI builds):
   - **Right-click** the app → **Open** → confirm, **or**
   - System Settings → Privacy & Security → allow the blocked app, **or** (last resort)  
     `xattr -cr /Applications/DevAlias.app`
4. Click the menu bar icon → **start hub**.

Gatekeeper warnings on CI zips are expected until a notarized Developer ID build is published — see [RELEASE.md](RELEASE.md).

## Install (from source)

```bash
brew install xcodegen
git clone https://github.com/niraj-prajapati/devalias.git
cd devalias
xcodegen generate
open DevAlias.xcodeproj   # Run, or:
xcodebuild -project DevAlias.xcodeproj -scheme DevAlias \
  -destination 'platform=macOS' build CODE_SIGN_IDENTITY="-"
```

## First run / config

Nothing required beyond starting the hub. Optional Settings:

| Setting | Default | Notes |
|---|---|---|
| High port | `49200` | Hub listen port; change if busy |
| Hostname alias | system LocalHostName | Used for `<alias>.local` |
| Port 80 | off | Admin once — `pf` redirect so phones can use `http://alias.local/` |
| Auto-start hub | off | Start hub when the app launches |
| Launch at login | off | SMAppService login item |
| QR mode | `.local` | Switch to **ip** in the menu if the phone can’t open `.local` |
| Ignored ports / processes | empty | Extra discovery filters |

Also allow **DevAlias** through the macOS firewall if phones can’t connect.

## Quick use

1. Start hub from the menu (or enable **auto-start hub** in Settings).
2. Scan the QR (`.local` by default) or switch to **ip** / open the LAN URL on your phone.
3. Optional: Settings → **enable** Port 80 (admin once) → `http://alias.local/`.
4. Tap a listener row or type a port and go.

## Security model

**App Sandbox is OFF** on purpose — discovery needs `lsof`/`libproc`, and Port 80 uses a narrow admin script (`pfctl`). Not for Mac App Store. Details: [SECURITY.md](SECURITY.md).

The GUI never runs as root. Port 80 changes go through bundled scripts + admin prompt (a least-privilege helper is roadmap-only; v1 uses osascript + bundled `Scripts/`).

## Port 80

Settings → enable (admin once) installs a pf anchor:

- Phones: Port 80 → **LAN IP**:`highPort`
- Mac browser: `lo0` hairpin → `127.0.0.1`:`highPort`
- Survives reboot; **Stop Hub does not remove it** — use Settings → remove Port 80

From a source checkout you can also:

```bash
sudo Scripts/uninstall-pf-anchor.sh   # manual remove
Scripts/install-pf-anchor.sh --dry-run
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| “App can’t be opened” / Gatekeeper | Right-click → Open, or Privacy & Security allow; see Install |
| Hub port in use | Settings → change high port → start hub |
| Firewall blocks phones | System Settings → Network → Firewall → allow DevAlias |
| No LAN IP | Join Wi‑Fi; disable VPN if it hides IPv4 |
| Port 80 / pf fails | Re-enable in Settings; check `/etc/pf.conf` markers |
| Port 80 busy | Disable AirPlay Receiver or stop other :80 |
| Phone `.local` flaky | Menu QR → **ip** (LAN URL) |
| AP isolation | Leave guest Wi‑Fi |
| Noisy listeners | Already filtered; Settings → advanced ignores |

## Uninstall

1. Settings → disable launch at login  
2. Settings → remove Port 80  
3. Quit → delete `DevAlias.app`  
4. Or (source tree): `sudo Scripts/uninstall-pf-anchor.sh`

## Docs

| Doc | Purpose |
|---|---|
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to contribute |
| [SECURITY.md](SECURITY.md) | Threat model / sandbox |
| [RELEASE.md](RELEASE.md) | Signing / notarization |
| [HOMEBREW-CASK.md](HOMEBREW-CASK.md) | Draft cask notes |
| [PROGRESS.md](PROGRESS.md) | Build status |

## License

[MIT](LICENSE)
