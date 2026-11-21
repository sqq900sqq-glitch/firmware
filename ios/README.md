# Bruce iOS companion app

A small SwiftUI app that opens the Bruce device's Web UI (default `http://bruce.local`).

## Build the IPA on GitHub

The workflow `.github/workflows/build_ipa.yml` builds an **unsigned** `Bruce.ipa` on a macOS runner.

- It runs automatically on pushes / pull requests that touch `ios/**`.
- Or run it manually: **Actions → Build iOS IPA → Run workflow**.
- Download the IPA from the run's **Artifacts** section.
- Pushing a tag like `ios-v1.0.0` also attaches the IPA to a GitHub Release.

Because the IPA is unsigned, install it with a sideloading tool that signs it
for you (AltStore, SideStore, Sideloadly, TrollStore, …).

## Build locally (macOS)

```sh
brew install xcodegen
cd ios
xcodegen generate
open Bruce.xcodeproj
```
