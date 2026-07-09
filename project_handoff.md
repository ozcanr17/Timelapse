# Timelapse — Project Handoff

Quick brief to resume development on another Claude/dev account. For full detail read `README.md` (architecture, monetization, compliance). This file is the fast on-ramp.

## What it is
Native **iOS** app (Swift 5 / SwiftUI / SwiftData / StoreKit 2 / AVFoundation), no third-party deps. "One photo a day" progress timelapses (beard, baby, plant, fitness…) with ghost-alignment capture, streaks/reminders, and MP4 export with overlays. Freemium + Pro (subscription + lifetime).

- **Bundle ID:** `rozcan.Timelapse` · **Version:** 1.0 (1) · **Min iOS:** 17.0
- **Owner:** Rıdvan Özcan

## Where the code is
- **Repo:** https://github.com/ozcanr17/Timelapse.git (branch `main`)
- **Local path (this machine):** `/Users/ridvanozcan/Desktop/workspace/Timelapse`
- **State at handoff:** working tree clean, `main` == `origin/main`, latest commit `b330c66` ("Softer glass + readable labels, WYSIWYG manual align, short smooth transitions, no-delay capture").

On the other account just:
```bash
git clone https://github.com/ozcanr17/Timelapse.git
cd Timelapse
open Timelapse.xcodeproj
```

## Build & test
Needs full **Xcode 16+** (not just Command Line Tools).
```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

# Run
xcodebuild build -scheme Timelapse -destination 'platform=iOS Simulator,name=iPhone 16'
# Test (74 unit tests: monetization, store override, export/speed, composer, cadence, repo, VMs)
xcodebuild test  -scheme Timelapse -destination 'platform=iOS Simulator,name=iPhone 16'
```
The shared **Timelapse** scheme references `Products.storekit`, so StoreKit prices work in the Simulator with no App Store Connect setup.

## Layout (start here)
- `TimelapseApp.swift` — entry, container + `StoreService` wiring
- `Models/CoreModels.swift` — `@Model Project` → `Entry`
- `Data/ProjectRepository.swift` — all persistence goes through this protocol (never SwiftData from views)
- `Features/Camera/` — capture + ghost alignment
- `Features/Export/` — `TimelapseComposer` (AVAssetWriter H.264), `FrameAligner` (Vision), export sheet/VM
- `Features/Store/` — `FeatureGate` (pure monetization rules), `StoreService` (`isPro` = single source of truth), paywall
- `Theme.swift` — design system / selectable palettes

Pattern: MVVM + protocol-backed services; view models are `@Observable @MainActor`; services injected so tests use fakes.

## House rules (important)
- **No comments in code.** Do not add code comments.
- **English-only identifiers.** UI is localized TR (base) + EN via `.xcstrings`.
- Minimal token usage; work step-by-step and wait for "continue" before large moves.

## Gotchas
- **Sign in with Apple + iCloud/CloudKit** are wired in `Timelapse.entitlements` but **disabled** (not referenced by `CODE_SIGN_ENTITLEMENTS`) — they need a **paid** Apple Developer account. Re-enable via target → Signing & Capabilities (see README §5).
- **DEBUG-only Pro backdoor:** Settings → tap version number 7× → "Geliştirici" → "Pro'yu Test Et." Does not exist in Release.
- Pro unlock in Release comes **only** from verified StoreKit purchases (`#if DEBUG` guards the override) — keep it that way (App Store 2.3.1 / 3.1.1).
- Two `CameraCaptureViewModelTests` can crash under simulator diagnostics if `xcode-select` points at CLT; point it at Xcode.app for a clean run.

## Pricing / products
| Product ID | Type | Price |
|---|---|---|
| `com.ridvan.timelapse.pro.monthly` | Auto-renewable (P1M) | $0.50/mo |
| `com.ridvan.timelapse.pro.lifetime` | Non-consumable | $3.99 |

Mirror these in App Store Connect for production.

## Open / next up (pre-submission checklist)
- [ ] Replace `LegalLinks.privacyPolicy` / `.support` with **hosted** URLs; enter Privacy Policy URL in App Store Connect.
- [ ] Create the two IAP products in App Store Connect (matching IDs/prices); submit with the build.
- [ ] Fill App Privacy questionnaire (Data Not Collected if photos stay local/iCloud-only, no analytics).
- [ ] Review notes explaining freemium limits + how to trigger the paywall.
- [ ] Confirm screenshots, app icon, age rating.

## Free-tier limits (in `FeatureGate`)
1 active project · 14 photos (15th → paywall) · 720×960 export with "TIMELAPSE" watermark. Pro removes all + 4K/no-watermark, iCloud backup, Smart Alignment, Couple Mode, Capture Together.
