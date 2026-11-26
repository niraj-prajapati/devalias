#!/bin/bash
# DevAlias — install pf rdr-anchor: TCP/80 → high port (idempotent).
# Inserts rdr-anchor in the *translation* section (before filtering), not at EOF.
set -euo pipefail

ANCHOR_NAME="com.nandroidex.devalias"
ANCHOR_PATH="/etc/pf.anchors/${ANCHOR_NAME}"
PF_CONF="/etc/pf.conf"
MARKER_BEGIN="# BEGIN com.nandroidex.devalias"
MARKER_END="# END com.nandroidex.devalias"
HIGH_PORT="49200"
INTERFACE="en0"
REDIRECT_TO=""
ANCHOR_FILE=""
DRY_RUN=0

usage() {
  cat <<EOF
Usage: $0 [--dry-run] [--high-port N] [--interface en0] [--redirect-to LAN_IP] [--anchor-file PATH]
Note: redirect target must be the Mac LAN IP (not 127.0.0.1) so phones can reach Port 80.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --high-port) HIGH_PORT="$2"; shift 2 ;;
    --interface) INTERFACE="$2"; shift 2 ;;
    --redirect-to) REDIRECT_TO="$2"; shift 2 ;;
    --anchor-file) ANCHOR_FILE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ -z "$REDIRECT_TO" ]]; then
  REDIRECT_TO="$(ipconfig getifaddr "$INTERFACE" 2>/dev/null || true)"
fi
if [[ -z "$REDIRECT_TO" ]]; then
  REDIRECT_TO="$(ipconfig getifaddr en0 2>/dev/null || true)"
fi
if [[ -z "$REDIRECT_TO" ]]; then
  echo "ERROR: --redirect-to LAN_IP is required (pf rdr to 127.0.0.1 breaks phone access on macOS)." >&2
  exit 12
fi

if /usr/sbin/lsof -nP -iTCP:80 -sTCP:LISTEN >/dev/null 2>&1; then
  echo "ERROR: Port 80 is already in use. Stop the listener before installing DevAlias forwarding." >&2
  /usr/sbin/lsof -nP -iTCP:80 -sTCP:LISTEN >&2 || true
  exit 10
fi

# NOTE: never use BODY="$(cat file)" — command substitution strips trailing newlines
# and pfctl then reports a syntax error on the last rdr line.
write_anchor_body() {
  local dest="$1"
  if [[ -n "$ANCHOR_FILE" && -f "$ANCHOR_FILE" ]]; then
    /bin/cp "$ANCHOR_FILE" "$dest"
  else
    IFACE_CLAUSE=""
    if [[ "$INTERFACE" != "all" && -n "$INTERFACE" ]]; then
      IFACE_CLAUSE=" on ${INTERFACE}"
    fi
    # LAN iface → phone traffic; lo0 → Mac browser hairpin to own .local / LAN IP.
    IFACE_NAME="${INTERFACE}"
    if [[ -z "$IFACE_NAME" || "$IFACE_NAME" == "all" ]]; then
      IFACE_NAME="en0"
    fi
    cat > "$dest" <<EOF
# DevAlias Port 80 -> ${REDIRECT_TO}:${HIGH_PORT} (LAN) + lo0 -> 127.0.0.1:${HIGH_PORT} (Mac)
rdr pass on ${IFACE_NAME} inet proto tcp from any to any port 80 -> ${REDIRECT_TO} port ${HIGH_PORT}
rdr pass on lo0 inet proto tcp from any to any port 80 -> 127.0.0.1 port ${HIGH_PORT}
EOF
  fi
  # Guarantee final newline (pfctl requires it).
  if [[ -s "$dest" ]] && [[ "$(tail -c1 "$dest" | wc -l)" -eq 0 ]]; then
    printf '\n' >> "$dest"
  fi
}

TMP_ANCHOR="$(mktemp)"
write_anchor_body "$TMP_ANCHOR"

echo "DevAlias pf install"
echo "  anchor: ${ANCHOR_PATH}"
echo "  high port: ${HIGH_PORT}"
echo "  interface: ${INTERFACE}"
echo "---- anchor ----"
cat "$TMP_ANCHOR"
echo "---- end ----"

# Preflight syntax check (does not load).
if ! /sbin/pfctl -a "$ANCHOR_NAME" -nf "$TMP_ANCHOR" >/tmp/devalias-pf-anchor-n.log 2>&1; then
  echo "ERROR: generated anchor failed pfctl syntax check:" >&2
  /usr/bin/grep -v -e 'No ALTQ' -e 'Use of -f option' /tmp/devalias-pf-anchor-n.log >&2 || cat /tmp/devalias-pf-anchor-n.log >&2
  rm -f "$TMP_ANCHOR"
  exit 11
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "(dry-run) would insert rdr-anchor after existing rdr-anchor lines,"
  echo "          and load-anchor after existing load-anchor lines."
  rm -f "$TMP_ANCHOR"
  exit 0
fi

if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: must run as root (sudo)" >&2
  rm -f "$TMP_ANCHOR"
  exit 1
fi

mkdir -p /etc/pf.anchors
/bin/cp "$TMP_ANCHOR" "$ANCHOR_PATH"
chmod 644 "$ANCHOR_PATH"
rm -f "$TMP_ANCHOR"

# Build a clean pf.conf:
# 1) strip any previous DevAlias marker block / leftover devalias lines
# 2) insert rdr-anchor among translation rules (after last rdr-anchor)
# 3) insert load anchor after last load-anchor
python3 - "$PF_CONF" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text() if path.exists() else ""
lines = text.splitlines()

begin = "# BEGIN com.nandroidex.devalias"
end = "# END com.nandroidex.devalias"
skip = False
cleaned = []
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
    cleaned.append(line)

rdr_line = 'rdr-anchor "com.nandroidex.devalias"'
load_line = 'load anchor "com.nandroidex.devalias" from "/etc/pf.anchors/com.nandroidex.devalias"'

out = list(cleaned)

def last_index(prefix: str):
    idx = None
    for i, line in enumerate(out):
        if line.strip().startswith(prefix):
            idx = i
    return idx

# Translation section: after last rdr-anchor, else after last nat-anchor, else before first filtering anchor.
rdr_idx = last_index("rdr-anchor ")
nat_idx = last_index("nat-anchor ")
filter_idx = None
for i, line in enumerate(out):
    s = line.strip()
    # Filtering anchors look like: anchor "…"  (not scrub/nat/rdr/dummynet/load)
    if s.startswith("anchor ") and not s.startswith("anchor \"com.nandroidex"):
        filter_idx = i
        break

if rdr_idx is not None:
    out.insert(rdr_idx + 1, rdr_line)
elif nat_idx is not None:
    out.insert(nat_idx + 1, rdr_line)
elif filter_idx is not None:
    out.insert(filter_idx, rdr_line)
else:
    out.insert(0, rdr_line)

load_idx = last_index("load anchor ")
if load_idx is not None:
    out.insert(load_idx + 1, load_line)
else:
    out.append(load_line)

path.write_text("\n".join(out) + "\n")
print(f"Updated {path}")
PY

chmod 644 "$PF_CONF"

# Enable pf (reference-counted on modern macOS) and reload.
/sbin/pfctl -e 2>/dev/null || true

# Reload main ruleset. The -f flush warning is expected on macOS; syntax must be valid.
set +e
RELOAD_OUT="$(/sbin/pfctl -f "$PF_CONF" 2>&1)"
RELOAD_RC=$?
set -e
# Filter noisy but harmless lines; keep real errors.
FILTERED="$(printf '%s\n' "$RELOAD_OUT" | /usr/bin/grep -v -e 'No ALTQ support' -e 'ALTQ related functions disabled' -e 'Use of -f option' || true)"
if [[ "$RELOAD_RC" -ne 0 ]]; then
  echo "$FILTERED" >&2
  echo "ERROR: pfctl failed to reload $PF_CONF (rc=$RELOAD_RC)" >&2
  exit "$RELOAD_RC"
fi

/sbin/pfctl -a "$ANCHOR_NAME" -f "$ANCHOR_PATH"

echo "OK: Port 80 → ${HIGH_PORT} installed (rdr-anchor in translation section; survives reboot)."
exit 0
