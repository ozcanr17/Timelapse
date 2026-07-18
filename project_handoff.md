# Flapse — Project Handoff

This is a compact on-ramp. `HANDOFF.md` is the authoritative live-status document; also read `README.md` for the feature tour and `YAYINLAMA_REHBERI.md` for App Store publishing.

## Project

Native iOS 17+ app built with Swift, SwiftUI, SwiftData, StoreKit 2, AVFoundation, Vision, ActivityKit, WidgetKit, CloudKit, and on-device Foundation Models. There are no third-party dependencies.

- Display name: **Flapse**
- App bundle ID: `rozcan.Flapse`
- Widget bundle ID: `rozcan.Flapse.Widgets`
- Team: `5ZYCHZ39QV`
- Repository: `https://github.com/ozcanr17/Timelapse.git`, branch `main`

## Build and test

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild build -scheme Timelapse -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild test -scheme Timelapse -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TimelapseTests
```

Use iPhone 17 because the iPhone 16 destination can match multiple runtimes. Trust `xcodebuild`, not SourceKit diagnostics from the IDE harness. The suite currently contains 112 unit tests.

## Architecture

- `Timelapse/TimelapseApp.swift`: app entry and service wiring
- `Timelapse/Models/CoreModels.swift`: SwiftData project and entry models
- `Timelapse/Data/ProjectRepository.swift`: persistence boundary
- `Timelapse/Features/Camera/`: capture and ghost alignment
- `Timelapse/Features/Export/`: composition, alignment, background rendering, and Live Activity
- `Timelapse/Features/Store/`: StoreKit, entitlement state, feature gating, and paywall
- `Timelapse/Features/Auth/`: optional Sign in with Apple and account-data deletion
- `Widgets/`: widgets and render Live Activity UI

The project uses MVVM with protocol-backed services and injectable fakes/in-memory stores for tests. Views must not bypass `ProjectRepository` to perform persistence work.

## House rules

- Do not add code comments.
- Use English identifiers.
- Turkish UI literals are localization keys. Every new user-facing string needs all 11 target translations in `Timelapse/Localizable.xcstrings`; widget strings also belong in `Widgets/Localizable.xcstrings`.
- Load `.agents/skills/tasteskill/SKILL.md` before changing SwiftUI presentation.
- Build, run unit tests, and push `main` after each approved batch.

## Monetization

Free users get one active project and 14 visible frames. Smart alignment is free and enabled by default; manual per-frame alignment is Pro.

| Product ID | Type | Reference price |
|---|---|---:|
| `com.ridvan.timelapse.pro.monthly` | Auto-renewable, one month | $0.49 |
| `com.ridvan.timelapse.pro.yearly` | Auto-renewable, one year | $4.99 |
| `com.ridvan.timelapse.pro.lifetime` | Non-consumable | $9.99 |

Both subscriptions promise a seven-day free trial, which must be configured identically in App Store Connect. Release entitlements come only from verified StoreKit purchases; the admin grant remains an intentional UserDefaults/iCloud KVS mechanism.

## Current release state

Code-side App Store preparation, signing, archive, export, legal pages, metadata drafts, optional sign-in, account deletion, and review compliance are complete. Remaining work is in App Store Connect: agreements/tax/banking, app and IAP records, screenshots and metadata, CloudKit Production deployment, upload, TestFlight, and review submission.

Do not claim or reintroduce drop detection. Do not list smart alignment as a Pro benefit. Keep `RenderActivityAttributes` byte-identical in the app and widget targets, and preserve the foreground retry for background hardware-encoder failures.
