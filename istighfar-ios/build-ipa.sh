#!/usr/bin/env bash
# Builds an unsigned Istighfar.ipa. Requires macOS with Xcode (iOS SDK).
set -euo pipefail
cd "$(dirname "$0")"
OUT=build; APP=$OUT/Payload/Istighfar.app
rm -rf "$OUT"; mkdir -p "$APP"

SDK=$(xcrun --sdk iphoneos --show-sdk-path)
xcrun --sdk iphoneos swiftc -O -sdk "$SDK" -target arm64-apple-ios14.0 \
  -framework UIKit -framework WebKit -framework CoreLocation \
  -framework UserNotifications -framework AVFoundation \
  App/main.swift -o "$APP/Istighfar"

cp App/Info.plist "$APP/Info.plist"
cp -R App/www "$APP/www"
cp App/ios-bridge.js "$APP/ios-bridge.js"
cp App/icon/AppIcon60x60@2x.png App/icon/AppIcon60x60@3x.png App/icon/AppIcon76x76.png \
   App/icon/AppIcon76x76@2x.png App/icon/AppIcon83.5x83.5@2x.png "$APP/"

# Compile an asset catalog (Assets.car) for the icon
XC=$OUT/Assets.xcassets/AppIcon.appiconset; mkdir -p "$XC"
cp App/icon/AppIcon1024.png "$XC/"
cat > "$XC/Contents.json" <<'J'
{"images":[{"filename":"AppIcon1024.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}
J
echo '{"info":{"author":"xcode","version":1}}' > "$OUT/Assets.xcassets/Contents.json"
xcrun actool "$OUT/Assets.xcassets" --compile "$APP" --platform iphoneos \
  --minimum-deployment-target 14.0 --app-icon AppIcon --target-device iphone --target-device ipad \
  --output-partial-info-plist "$OUT/assetinfo.plist" || echo "actool failed; using loose PNG icons"

plutil -convert binary1 "$APP/Info.plist"
echo -n "APPL????" > "$APP/PkgInfo"
# Ad-hoc signature so the bundle is well-formed; re-sign with your own certificate to install.
codesign --force --sign - --timestamp=none "$APP" || true

(cd "$OUT" && zip -qr -y Istighfar.ipa Payload)
mkdir -p dist && cp "$OUT/Istighfar.ipa" dist/Istighfar.ipa
ls -la dist/Istighfar.ipa
