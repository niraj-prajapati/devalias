# Contributing to DevAlias

## Architecture map

| Area | Path |
|---|---|
| App entry / menu | `DevAlias/App/`, `DevAlias/MenuBar/` |
| Hub HTTP | `DevAlias/Server/` (+ `Resources/dashboard.html`) |
| mDNS | `DevAlias/MDNS/` |
| Discovery | `DevAlias/Discovery/` — scanner → filter → heuristics |
| pf Port 80 | `DevAlias/Privileged/` + `Scripts/*-pf-anchor.sh` |
| Settings | `DevAlias/State/SettingsStore.swift` |
| Tests | `Tests/` |

Also see [SECURITY.md](SECURITY.md), [RELEASE.md](RELEASE.md), [PROGRESS.md](PROGRESS.md).

## Where to add a stack heuristic

1. Extend `TechStack` if needed (`DevAlias/Discovery/Models/TechStack.swift`).
2. Teach `StackHeuristics.infer` — prefer **process name**, not cwd alone.
3. Allowlist the binary in `SystemProcessFilter.developerAllowlist` if it should appear.
4. Add a fixture assertion in `Tests/DiscoveryTests/DiscoveryEngineTests.swift`.

## Discovery false positives

1. Add to `SystemProcessFilter.denylistNames` or ignored ports.
2. Or use Settings → advanced ignores.
3. Open an issue with process name, port, and `lsof -nP -iTCP:PORT -sTCP:LISTEN`.

## Build & test

```bash
brew install xcodegen   # once
xcodegen generate
xcodebuild -project DevAlias.xcodeproj -scheme DevAlias \
  -destination 'platform=macOS' test CODE_SIGN_IDENTITY="-"
```

## Privileged changes

Port 80 scripts under `Scripts/` are the auditable source of truth. Do not widen the admin surface beyond enable/disable/status.
