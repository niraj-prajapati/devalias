#!/bin/bash
# DevAlias — remove pf rdr-anchor lines and anchor file (idempotent).
set -euo pipefail

ANCHOR_NAME="com.nandroidex.devalias"
ANCHOR_PATH="/etc/pf.anchors/${ANCHOR_NAME}"
PF_CONF="/etc/pf.conf"
MARKER_BEGIN="# BEGIN com.nandroidex.devalias"
MARKER_END="# END com.nandroidex.devalias"
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      echo "Usage: $0 [--dry-run]"; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

echo "DevAlias pf uninstall"
echo "  will flush anchor ${ANCHOR_NAME}"
echo "  will remove ${ANCHOR_PATH}"
echo "  will strip DevAlias lines from ${PF_CONF}"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "(dry-run) no changes written"
  exit 0
fi

if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: must run as root (sudo)" >&2
  exit 1
fi

/sbin/pfctl -a "$ANCHOR_NAME" -F all 2>/dev/null || true
rm -f "$ANCHOR_PATH"

if [[ -f "$PF_CONF" ]]; then
  python3 - "$PF_CONF" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
lines = path.read_text().splitlines()
begin = "# BEGIN com.nandroidex.devalias"
end = "# END com.nandroidex.devalias"
skip = False
out = []
for line in lines:
    if line.strip() == begin:
        skip = True
        continue
    if line.strip() == end:
        skip = False
        continue
    if skip:
        continue
    if "com.nandroidex.devalias" in line:
        continue
    out.append(line)
path.write_text("\n".join(out) + "\n")
print(f"Cleaned {path}")
PY
  chmod 644 "$PF_CONF"
  set +e
  /sbin/pfctl -f "$PF_CONF" >/tmp/devalias-pf-uninstall.log 2>&1
  set -e
fi

echo "OK: DevAlias Port 80 forwarding removed."
exit 0
