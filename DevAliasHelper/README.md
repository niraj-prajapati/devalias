# DevAliasHelper

**Status (1.0):** Not shipped. Port 80 uses admin `osascript` + `Scripts/*-pf-anchor.sh` in the main app.

**Design:** [docs/checklists/PRIVILEGED-HELPER.md](../docs/checklists/PRIVILEGED-HELPER.md)

When implemented, this target should be an SMAppService helper that exposes **only**:

- `status()`
- `enable(interface:highPort:redirectIPv4:)`
- `disable()`

No shell from client strings, no discovery, no hub control. Keep `Scripts/` as the auditable reference and recovery path.
