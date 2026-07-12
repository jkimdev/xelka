# xelka — Release Checklist

Status as of the monetization + release-prep work on `feat/p0-camera-features`.

## ✅ Done in code / project config

- **App icon** — 1024² pixel-art camera icon wired as a single universal iOS
  icon (`xelka/Assets.xcassets/AppIcon.appiconset/`). First-pass/placeholder;
  swap for final art anytime by replacing `AppIcon-1024.png`.
- **Privacy manifest** — `xelka/PrivacyInfo.xcprivacy`: no tracking, no data
  collected, no required-reason APIs (app is fully on-device, no network/SDKs).
- **Export compliance** — `ITSAppUsesNonExemptEncryption = NO` (skips the
  per-submission prompt; only exempt system crypto is used).
- **Usage strings** — camera + photo add/read descriptions already present.
- **StoreKit** — one-time non-consumable Pro unlock implemented (`ProStore`,
  `PaywallView`), watermark + style/video gating. Restore Purchases present.

## ⛔ You must do (needs the Apple Developer account)

1. **App Store Connect — app record**: create the app under bundle ID
   `com.jimmythegenius.xelka` (team `5H679H8G3X`).
2. **Register the IAP product** (must match the code exactly):
   - Type: **Non-Consumable**
   - Product ID: **`com.jimmythegenius.xelka.pro`**
   - Price: **$4.99 tier** (≈ ₩6,600) — the research target was ₩5,900–7,900.
   - Localized display name / description (EN + KO + JA recommended).
   - The App ID has In-App Purchase enabled by default — no entitlement file
     needed. Submit the IAP **with** the app's first version for review.
3. **Signing / upload**: automatic signing is on. Archive for
   "Any iOS Device", let Xcode manage the distribution cert/profile, upload to
   App Store Connect → TestFlight.
4. **Real-device sandbox test** (the one thing not auto-verified — SKTestSession
   is broken on the iOS 26 simulator): install via TestFlight, then verify
   - locked style / Video mode → paywall shows the real price,
   - purchase → watermark gone + all styles + video unlocked,
   - delete & reinstall → **Restore Purchase** re-unlocks.
5. **Store listing**: screenshots (6.9"/6.7" + others), description, keywords,
   support URL, **privacy policy URL** (required because the app has IAP),
   age-rating questionnaire.

## Deployment target — lowered to iOS 18.0 ✅

Was `26.2` (excluded almost the whole audience). Now **`IPHONEOS_DEPLOYMENT_TARGET
= 18.0`** on all targets. Availability audit passed: a clean build against the
iOS 26 SDK with the 18.0 target produced **no availability errors**, so every
API in use (StoreKit 2, SwiftData/@Observable, PhotosPicker, the Metal CIKernel)
is iOS 18-safe. No iOS 18 simulator is installed locally — do a real-device (or
downloaded iOS 18 sim) smoke test of camera + live preview + purchase before
launch to confirm runtime behavior.

## Notes / limitations

- The purchase transaction path is validated only manually (step 4) — the iOS 26
  simulator's local StoreKit testing returns 0 products (Apple tooling bug).
  Logic is covered by `MonetizationTests`; the gating→paywall UI by
  `PaywallUITests`.
- `xelka.storekit` (repo root) is dev-only, referenced by the run scheme for
  local StoreKit testing in Xcode. It is not bundled into the app.
- `SUPPORTED_PLATFORMS` still lists mac/visionOS from the template; iOS is the
  ship target. Tighten if you want to avoid confusion.
