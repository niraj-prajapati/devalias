# DevAlias progress

**Current:** v0.1.0 packaged — private repo / CI on `main`; tag `v0.1.0` after first green CI  
**Next:** Optional reboot/sleep spot-check; Developer ID notarization; Phase 10 privileged helper when scheduled

| Phase | Milestone | Status |
|---|---|---|
| 0 Scaffolding | M1 MVP Core | **pass** |
| 1 Domain + settings store | M1 MVP Core | **pass** |
| 2 Hub HTTP server | M1 MVP Core | **pass** |
| 3 Menu Bar UI shell | M1 MVP Core | **pass** |
| 4 mDNS alias broadcaster | M2 Reachability | **pass** |
| 5 pfctl Port 80 forwarder | M2 Reachability | **pass** |
| 6 Discovery engine | M3 Discovery + Mobile | **pass** |
| 7 Mobile dashboard polish | M3 Discovery + Mobile | **pass** |
| 8 Settings polish + login item | M4 Polish + OSS | **pass** |
| 9 Open-source release | M4 Polish + OSS | **pass** |
| 10 Post-1.0 backlog | After 1.0 | pending (privileged helper XPC) |

### Release checklist

| Step | Status | Notes |
|---|---|---|
| P9-S01 | **pass** | MIT LICENSE, public README, SECURITY |
| P9-S02 | **pass** | `.github/workflows/ci.yml` + badge |
| P9-S03 | **pass** | `Scripts/notarize.sh`, `RELEASE.md`, `release.yml` (ad-hoc + optional notarize) |
| P9-S04 | **pass*** | Helper designed; osascript + scripts remain v1 (documented fallback) |
| P9-S05 | **pass** | CONTRIBUTING, issue templates, HOMEBREW-CASK.md |
| P9-S06 | **pass** | QA matrix signed 2026-11-26 (internal); tag when CI green |
