# Homebrew cask (draft)

Not published yet — notes for a future tap.

## Suggested cask sketch

```ruby
cask "devalias" do
  version "0.1.0"
  sha256 "REPLACE_WITH_RELEASE_SHA256"

  url "https://github.com/niraj-prajapati/devalias/releases/download/v#{version}/DevAlias.zip"
  name "DevAlias"
  desc "Menu bar hub for mobile-testing local servers"
  homepage "https://github.com/niraj-prajapati/devalias"

  app "DevAlias.app"

  zap trash: [
    "~/Library/Preferences/com.nandroidex.devalias.plist",
  ]
end
```

## Caveats for the tap README

- App Sandbox is **off** (required for discovery + pf).
- Port 80 needs an admin password once; reboot survival documented in-app.
- Prefer **notarized** zip from GitHub Releases; ad-hoc CI builds need Gatekeeper docs.
- After uninstall, users may still need `sudo Scripts/uninstall-pf-anchor.sh` if Port 80 was enabled.
