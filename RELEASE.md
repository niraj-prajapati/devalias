# Release & signing

## Ad-hoc (CI / local without Developer ID)

```bash
xcodegen generate
xcodebuild -project DevAlias.xcodeproj -scheme DevAlias -configuration Release \
  -destination 'platform=macOS' build CODE_SIGN_IDENTITY="-"
```

GitHub Actions `release.yml` on tag `v*` uploads an **ad-hoc** `DevAlias.zip` + sha256.  
Gatekeeper will warn on download — expected without Developer ID notarization.

## Developer ID + notarization

1. Build Release `DevAlias.app`
2. Export secrets (never commit):

```bash
export DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)"
export APPLE_ID="you@example.com"
export APPLE_TEAM_ID="TEAMID"
export APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
export APP_PATH="/path/to/DevAlias.app"
```

3. Run:

```bash
chmod +x Scripts/notarize.sh
./Scripts/notarize.sh
```

Output: `dist/DevAlias.zip` + `dist/DevAlias.zip.sha256` (stapled).

## Source-only

If signing keys are unavailable, ship **source + CI ad-hoc builds** and state clearly in the GitHub Release notes that users should build from source or accept Gatekeeper overrides (`xattr -cr DevAlias.app` after unzip is a last resort — prefer notarized builds).
