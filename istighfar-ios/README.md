# Istighfar — iOS port

iOS version of the Android `Istighfar.apk` (package `com.istighfar.app`).

The Android app is a WebView shell that loads `assets/istighfar.html` and exposes a
JavaScript bridge named `Android`. This port keeps the original HTML/CSS/JS
(`App/www/`, unchanged) and re-implements that bridge in Swift (`App/main.swift`,
`App/ios-bridge.js`):

| Android bridge method | iOS implementation |
|---|---|
| `systemDark()` / `setBarColor(d)` | trait collection / status bar style |
| `notifEnabled()` / `setNotifications(v)` | UserNotifications, daily istighfar reminders |
| `requestLocation()` | CoreLocation + CLGeocoder (Arabic) → `__locResult` |
| `share(text)` | UIActivityViewController |
| `appVersion()` / `checkUpdate()` | bundle version; always "up to date" (no APK self-update on iOS) |
| `installUpdate()` | not applicable → `__updateFail` |
| `setPrayerAlarms()` | no-op (already disabled in the web code) |
| hardware back button | edge-swipe gesture → `window.__back()` |
| `navigator.vibrate` | haptic feedback |
| compass / camera (Qibla) | CLHeading → `deviceorientation`; AVCapture preview behind the web view |

## Build
`./build-ipa.sh` on macOS with Xcode, or push to the branch and the
`Istighfar iOS IPA` workflow builds `dist/Istighfar.ipa` on a macOS runner.

The IPA is not signed with a distribution certificate; install it with
Sideloadly, AltStore, TrollStore, or re-sign it with your own Apple ID / certificate.
