# Security model

## Why App Sandbox is off

DevAlias must:

- Inspect listen sockets / process paths (`lsof`, `libproc`) for discovery
- Optionally install a **narrow** `pfctl` Port 80 redirect via admin scripts

Mac App Store sandbox cannot support this. Distribution is **Developer ID / GitHub**, not MAS.

## What runs as root

| Action | Mechanism (v1) |
|---|---|
| Enable / disable Port 80 pf anchor | Bundled `Scripts/install-pf-anchor.sh` / `uninstall-pf-anchor.sh` via admin `osascript` |
| Optional system LocalHostName | `scutil` via admin helper path |

The Menu Bar app and hub HTTP server **never** run as root.

## Attack surface

- Hub listens on LAN (default `:49200`) — only expose on trusted Wi‑Fi.
- Dashboard is a local launcher; treat LAN peers as semi-trusted.
- pf rules only redirect TCP/80 → configured LAN IP / lo0 hairpin → hub high port.
- Discovery reads process metadata; denylist/allowlist reduce noise, not a security boundary.

## Privileged helper (roadmap)

v1 ships the osascript + script path. A least-privilege SMAppService helper (enable/disable/status only) is planned post-1.0; see `DevAliasHelper/README.md`.

## Reporting

Please open a private security advisory or contact the maintainer. Include: macOS version, DevAlias version, and whether Port 80 / Login Item were enabled.
