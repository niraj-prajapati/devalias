#!/usr/bin/env bash
# DevAlias — Developer ID sign + notarize + staple (Phase 9).
# Secrets must come from the environment / CI — never commit them.
#
# Required env:
#   DEVELOPER_ID_APPLICATION   e.g. "Developer ID Application: Name (TEAMID)"
#   APPLE_ID                   Apple ID email
#   APPLE_TEAM_ID              10-char team id
#   APPLE_APP_SPECIFIC_PASSWORD
#
# Optional:
#   APP_PATH                   path to DevAlias.app (default: DerivedData Release)
#   SKIP_NOTARY=1              sign only
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${APP_PATH:-}"
OUT_DIR="${OUT_DIR:-$ROOT/dist}"

if [[ -z "$APP_PATH" ]]; then
  CANDIDATES=(
    "$ROOT/build/DerivedData/Build/Products/Release/DevAlias.app"
    "$ROOT/build/Release/DevAlias.app"
  )
  for c in "${CANDIDATES[@]}"; do
    if [[ -d "$c" ]]; then APP_PATH="$c"; break; fi
  done
fi

if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "ERROR: DevAlias.app not found. Build Release first, or set APP_PATH=." >&2
  echo "  xcodegen generate && xcodebuild -project DevAlias.xcodeproj -scheme DevAlias -configuration Release -destination 'platform=macOS' build" >&2
  exit 1
fi

: "${DEVELOPER_ID_APPLICATION:?Set DEVELOPER_ID_APPLICATION}"

mkdir -p "$OUT_DIR"
echo "Signing $APP_PATH with $DEVELOPER_ID_APPLICATION"
codesign --force --deep --options runtime --sign "$DEVELOPER_ID_APPLICATION" "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

ZIP="$OUT_DIR/DevAlias-notarize.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP_PATH" "$ZIP"

if [[ "${SKIP_NOTARY:-0}" == "1" ]]; then
  echo "SKIP_NOTARY=1 — signed zip at $ZIP"
  shasum -a 256 "$ZIP" | tee "$ZIP.sha256"
  exit 0
fi

: "${APPLE_ID:?Set APPLE_ID}"
: "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID}"
: "${APPLE_APP_SPECIFIC_PASSWORD:?Set APPLE_APP_SPECIFIC_PASSWORD}"

echo "Submitting to notarytool…"
xcrun notarytool submit "$ZIP" \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_SPECIFIC_PASSWORD" \
  --wait

echo "Stapling…"
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

DIST_ZIP="$OUT_DIR/DevAlias.zip"
rm -f "$DIST_ZIP"
ditto -c -k --keepParent "$APP_PATH" "$DIST_ZIP"
shasum -a 256 "$DIST_ZIP" | tee "$DIST_ZIP.sha256"
echo "OK: $DIST_ZIP"
exit 0
