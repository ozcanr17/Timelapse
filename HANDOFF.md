# HANDOFF — Flapse iOS App

Written for a fresh session with zero context. Read this first, then `README.md` (feature tour), `YAYINLAMA_REHBERI.md` (App Store publishing guide, Turkish, with live status), and `project_handoff.md` (older on-ramp; still valid for house rules).

## What this project is

Native iOS app (Swift/SwiftUI/SwiftData/StoreKit 2/AVFoundation/Vision/ActivityKit, **no third-party deps**). "One photo a day" progress timelapses with smart alignment, streaks, background rendering with a Dynamic Island Live Activity, in-app saved-video library, photo editor, widgets, and freemium monetization.

- Local path: `/Users/ridvanozcan/Desktop/workspace/Flapse`
- Repo: `https://github.com/ozcanr17/Flapse.git`, branch `main`. App changes are pushed after each batch; preserve any unrelated owner-owned working-tree changes.
- Owner: Rıdvan Özcan (`ridvanozcan7@gmail.com`), display name **Flapse**, bundle ID **`rozcan.Flapse`**, widget `rozcan.Flapse.Widgets`, team `5ZYCHZ39QV`, min iOS 17, tested on an iOS 26 device with Dynamic Island.

## Build & test

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild build -scheme Flapse -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild test  -scheme Flapse -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FlapseTests
```

**130 unit tests**, all green at handoff. The full UI journey test is also green. Use **iPhone 17** as destination ("iPhone 16" matches multiple runtimes and errors). SourceKit diagnostics in the IDE harness are noise ("No such module UIKit") — trust `xcodebuild` only. Release build has **zero warnings**.

## House rules (from the owner — do not break)

- **No comments in code.** (Existing Turkish `///` doc comments predate the rule; don't add new ones.)
- English identifiers; UI strings are Turkish literals used as keys in `Flapse/Localizable.xcstrings` (12 languages: tr source + ar de en es fr hi ja ko pt ru zh-Hans). **Every new user-facing string needs translations in all 11 target languages** — pattern: a Python script that inserts `localizations.<lang>.stringUnit` entries (see git history). `String(localized:bundle:.appLanguage)` in Swift code; plain `LocalizedStringKey` Text works too. **The widget extension now has its own catalog** (`Widgets/Localizable.xcstrings`, same 12 languages) — keep it in sync for widget strings.
- Owner sends screenshots/screen recordings as feedback, iterates in small batches. Build + run unit tests + **push to origin/main after every batch** (they install on device from this repo).
- UI work must follow `.claude/skills/tasteskill` (calm native Apple HIG; no neon/gaming styling).

## PUBLISHING STATUS (2026-07-18) — the current focus

The app is **technically ready for App Store submission**. State of the pipeline:

✅ **Done & verified:**
- Apple Developer Program membership ACTIVE (team `5ZYCHZ39QV`). Verified end-to-end from CLI: `xcodebuild archive -allowProvisioningUpdates` succeeded, profiles auto-minted for both targets, all entitlements (SIWA, iCloud/CloudKit, aps-environment, App Groups) confirmed in the signed archive via `codesign -d --entitlements`, and `-exportArchive` with root `ExportOptions.plist` produced a real App Store `.ipa` (cloud-managed distribution signing; only an Apple Development cert exists locally and that's fine).
- GitHub Pages LIVE (`main` `/docs`): `https://ozcanr17.github.io/Flapse/privacy`, `/support`, `/` all 200 and Flapse-branded. The stale flat `docs/privacy.html`/`support.html` were DELETED because Pages served them at extensionless URLs, shadowing the good `docs/privacy/index.html` versions — **do not re-add flat files next to same-named directories in docs/**.
- App Review compliance implemented: optional sign-in ("Giriş yapmadan devam et" in `SignInGateSheet`, `auth.gateSkipped` AppStorage), account deletion (Settings → Hesap → Hesabı sil → `AuthService.deleteAccountData()` clears identity + admin grant from UserDefaults and iCloud KVS), paywall auto-renew disclosure + working Terms (Apple std EULA) & Privacy links, camera-denied → "Ayarları Aç", rating prompt (once per version, after first "Uygulamada sakla" success).
- Metadata kit `docs/AppStoreListing.md` is accurate and copy-paste ready (drop-detection claim removed — that feature was deleted from the app; auto-sort wording says "AI suggests, you confirm"; App Privacy = **Data Not Collected**; review notes mention optional sign-in + account deletion path).
- **Prices (halved 2026-07-18)**: monthly **$0.49**, yearly **$4.99**, lifetime **$9.99** (TR: 24,99₺ / 249,99₺ / 499,99₺). Product IDs: `com.ridvan.timelapse.pro.monthly|yearly|lifetime`. `Products.storekit` (attached to the shared scheme — the ONLY StoreKit config; a duplicate Configuration.storekit was removed) mirrors these. Real prices get set in ASC when creating IAPs.
- Small Business Program: applied, approval pending — does NOT block release; 15% commission applies once approved.

⏳ **Remaining = App Store Connect web work (owner, step-by-step in `YAYINLAMA_REHBERI.md`):**
1. Business → Paid Applications agreement + bank + tax (IAPs can't be created without it).
2. Create app record (`rozcan.Flapse`), 3 IAPs + 7-day free trials on both subs.
3. Paste metadata from `docs/AppStoreListing.md`; screenshots on device (6.9"); CloudKit schema → Production.
4. Archive/Upload via Organizer (or CLI with root `ExportOptions.plist`), TestFlight pass, submit.

## Recent session work (2026-07-17/18, all pushed)

- **Cross-device backup preference**: `CloudBackupPreference` mirrors the Pro iCloud-backup toggle through `NSUbiquitousKeyValueStore`; a newly received preference requests one restart before SwiftData opens the cloud-backed store. Sign in with Apple is explicitly distinguished from the device-level iCloud account required by CloudKit. UI-test containers now force `cloudKitDatabase: .none` so tests cannot import real private-database records.
- **Home/UI performance pass**: heavy tab panes moved from a simultaneously animated `ZStack` to native `TabView` lifecycle management; expensive blurred/drawing-group fire borders became lightweight, glow-free streak accents; the Home screen now prioritizes a due capture, uses a calm 2×2 stats grid, and shows a real first-project empty state. Onboarding typography, Reduce Transparency, Dynamic Type usage, tab selection, and VoiceOver duplication were improved.
- **Capture/project polish**: front-camera preview and photo output both explicitly mirror, so the saved selfie matches the familiar on-screen view; the back camera remains unmirrored. Projects sort by latest capture activity with creation date as fallback; the streak border uses a slow, glow-free angular motion and respects Reduce Motion.
- **Reliable presentation/import flows**: Settings welcome replay now dismisses and selects Home; completed manual imports return to their selected project without racing SwiftUI's dismiss environment; a full-screen system `PHPickerViewController` supports ordered current-format transfers plus file/data fallbacks, including hidden-library selection after system authentication without requesting broad library access.
- **Entry-level Recently Deleted**: deleting a frame now soft-deletes it for 30 days. Settings shows deleted photos alongside projects and saved videos with restore/permanent-delete actions; automatic purging and thumbnail invalidation are covered by repository tests.
- **Couple-mode identity order and safe framing**: smart mode compares on-device Vision face feature prints against the first reliable two-face frame and only mirrors confidently swapped frames; it no longer applies face-based scale, translation or rotation. Couple frames use aspect-fit inside the selected video ratio, cap automatic zoom at 1× and preserve both people with a softened fill behind any unused canvas area. No identity or biometric data leaves the device or is persisted.
- **Unified photo editor**: the former crop action opens a native editor with free, 9:16, 4:3, 3:4 and 16:9 crop ratios plus pan/zoom, horizontal flip, vertical flip, 90-degree rotation, reset and save/cancel semantics. Pixel and crop-geometry tests cover transform direction, dimensions, centered crops and pan bounds.
- **Large-project/photo-editor performance**: project detail fetches only its live entries with SwiftData, renders the timeline lazily, and the full-screen viewer keeps only the selected page plus its immediate neighbors alive. UI images use a memory-cost-limited downsample cache while original photo data remains untouched; revision-based keys refresh edited thumbnails immediately without flushing every cached image. Free crop now has a draggable aspect handle, controls live in a stable bottom panel, and final edits render from the original full-resolution source.
- **Localization audit**: the app and Info.plist catalogs have complete translations for all 11 target locales, with stale machine-state entries resolved and recent jargon rewritten naturally per language.
- **Widget redesign**: Today supports small/medium, Activity supports small/medium/large, Projects supports medium/large, and the Lock Screen widget supports inline/rectangular/circular families. The new layouts use adaptive system surfaces, restrained accent color and photo-first compositions without glow.
- **Final Flapse rename**: the app target/module/product, source/test folders, Xcode project and scheme are named Flapse. The GitHub repository, Pages paths and local repository folder also use Flapse; domain terms such as `TimelapseComposer` and fixed StoreKit product identifiers intentionally remain unchanged.

1. **Security/bug sweep round 2**: widget deep link `flapse://capture` now enforces `FeatureGate.canAddEntry` (was a free-tier bypass); `CameraService` capture continuation race fixed (delegate hops to `sessionQueue`, takes continuation atomically).
2. **Owner-reported fixes**: PhotoImportSheet "Bitti" not dismissing — root cause: PhotosPicker inside a sheet breaks the `dismiss` environment; fix: presenters clear `activeSheet` via `onFinished` (keep this pattern). Sign-in gate dead-end fixed: pending intent (add/import) continues after sign-in OR skip.
3. **Photo editor** (`Features/ProjectDetail/PhotoCropView.swift`): opened from the edit icon in `EntryViewerView` top bar; pinch/drag crop with thirds grid, horizontal/vertical flip and 90-degree rotation; keeps the crop aspect consistent and saves via `repository.replaceImage` (invalidates thumbnails). Entry viewer share image refreshes via task id keyed on `imageData?.count`.
4. **Pre-launch audit fixes**: import-into-new-project rolls back the created project if import fails (was leaking an empty project consuming the free slot; 4 new tests in `PhotoImportViewModelTests`); paywall shows retry state instead of hardcoded fallback prices in Release (`loadFailed`; fallback is `#if DEBUG` only); `hasTrial` honors `isEligibleForIntroOffer`; widget fully localized.
5. **Docs**: `YAYINLAMA_REHBERI.md` (Turkish publishing guide with ✅ status per step), `ExportOptions.plist`, AppStoreListing accuracy pass, price halving everywhere.

## Older session summaries (still relevant)

- 4-tab liquid-glass shell (`MainTabView`), drag-to-select capsule bar, Projects pane `.id` reset token (bumps only on re-tap or 0.5s after leaving).
- Background rendering (`TimelapseRenderService`) + Live Activity/Dynamic Island; `writerFailed` auto-retry on foreground (iOS kills the hardware encoder in background — never remove the retry).
- 7-day trash for saved timelapses, 30-day trash for projects and individual photos (Settings → Son Silinenler).
- Smart alignment is FREE and default-on; only manual per-frame alignment is Pro. **Do not reintroduce it as a Pro bullet.**
- Auto-capture (`AutoCaptureFlow`): always confirm, never silently auto-assign. Matcher scores mean of top-3 nearest signatures.
- Beat sync: strictly one cut per beat via `loopedCutTimes`; **drop detection was removed — do not reintroduce without owner sign-off, and it must not be claimed in marketing copy.**
- Camera prewarm via `CameraService.shared.prewarm()`; call `.stop()` when a capture flow is cancelled before presenting.
- Photos saving via `PhotoLibrarySaver` (add-only auth, `.photosDeniedAlert`).
- No networking at all — "Data Not Collected" stays accurate. CaptionWriter is on-device FoundationModels. StoreKit entitlements verified, never persisted. Admin Pro rides UserDefaults/iCloud KVS by design (`AuthService.adminEmailHashes`). `CKShare.publicPermission = .readWrite` is required for link-invite UX — revisit before marketing Birlikte Çekim broadly.

## Pitfalls — DO NOT repeat

1. **Liquid glass nesting**: bar = `liquidGlassCapsule` on icon row; selection capsule = `.overlay` above bar glass; duplicate non-hit-testing icon row on top. Don't "simplify".
2. **Live Activity images**: oversized images render as a gray box. `Widgets/Assets.xcassets/AppLogo.imageset` is 128px on purpose and must be the real AppIcon copy.
3. **`.id()` resets kill animations** — Projects reset token timing (see above).
4. **Hardware encoder dies in background** → keep the foreground retry mechanism.
5. **Main-thread SwiftData faulting**: never read `entry.imageData` in computed props re-evaluated per body pass; cache in `@State` once or use `ImageDownsampler.cachedImage`.
6. **Toolbar buttons on iOS 26**: plain 21pt icons in 30pt frames (`ProjectDetailView.toolbarIcon`); let the system provide glass.
7. **Front camera mirroring** is explicitly enabled on both preview-layer and photo-output connections; back-camera preview/output stay unmirrored. Don't flip in post.
8. **`RenderActivityAttributes` is duplicated** in `Flapse/Features/Export/RenderActivity.swift` and `Widgets/RenderLiveActivity.swift` — keep byte-identical.
9. **QR in outro** must be drawn via `UIImage(cgImage:).draw` (CGContext draw mirrors it).
10. **Monetization copy accuracy**: if gating or pricing changes, update Paywall, Welcome, Settings, README, `docs/AppStoreListing.md`, and `Products.storekit` in the same commit.
11. **`dismiss` environment breaks after PhotosPicker in a sheet** — dismiss via the presenter's item binding (`onFinished` → `activeSheet = nil`).
12. **GitHub Pages serves flat `foo.html` over `foo/index.html`** at extensionless URLs — don't re-add flat duplicates in `docs/`.

## Key file map

- `Flapse/MainTabView.swift` — tab shell, glass bar, deep link (`flapse://capture`, entry-limit gated)
- `Flapse/Features/Export/TimelapseRenderService.swift` — background jobs, retry, `TimelapseLibrary`
- `Flapse/Features/Export/TimelapseExportSheet.swift` — studio; cached `frames` @State; review prompt
- `Flapse/Features/Export/TimelapseComposer.swift` — render pipeline, outro + QR
- `Flapse/Features/ProjectDetail/PhotoCropView.swift` — crop/flip/rotate photo editor
- `Flapse/Features/Import/PhotoImportSheet.swift` + `PhotoImportViewModel.swift` — import, rollback-on-failure
- `Flapse/Features/Auth/AuthService.swift` + `SignInGateSheet.swift` — optional sign-in, account deletion
- `Flapse/Features/Store/` — StoreService (intro-offer eligibility), PaywallView/ViewModel (retry state)
- `Widgets/FlapseWidgets.swift` + `Widgets/Localizable.xcstrings` — widgets, localized
- `docs/` — GitHub Pages (LIVE) + `AppStoreListing.md` (ASC copy-paste kit)
- `YAYINLAMA_REHBERI.md`, `RELEASE_CHECKLIST.md`, `ExportOptions.plist`, `Products.storekit` — publishing kit
