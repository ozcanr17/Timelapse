# HANDOFF — Flapse (Timelapse) iOS App

Written for a fresh session with zero context. Read this first, then `README.md` (full feature tour) and `project_handoff.md` (older on-ramp; still valid for build/test commands and house rules).

## What this project is

Native iOS app (Swift/SwiftUI/SwiftData/StoreKit 2/AVFoundation/Vision/ActivityKit, **no third-party deps**). "One photo a day" progress timelapses with smart alignment, streaks, background rendering with a Dynamic Island Live Activity, an in-app saved-video library, widgets, and freemium monetization.

- Local path: `/Users/ridvanozcan/Desktop/workspace/Timelapse`
- Repo: `https://github.com/ozcanr17/Timelapse.git`, branch `main`. Working tree clean at handoff; everything is pushed (last commit: bug/security sweep).
- Owner: Rıdvan Özcan (`ridvanozcan7@gmail.com`), display name **Flapse**, bundle ID `rozcan.Timelapse`, min iOS 17, tested on an iOS 26 device with Dynamic Island.

## Build & test

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild build -scheme Timelapse -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild test  -scheme Timelapse -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TimelapseTests
```

108 unit tests, all green at handoff. Use **iPhone 17** as the destination ("iPhone 16" matches multiple runtimes and errors). SourceKit diagnostics in the IDE harness are noise ("No such module UIKit" etc.) — trust `xcodebuild` only.

## House rules (from the owner — do not break)

- **No comments in code.** Never add code comments (existing Turkish `///` doc comments predate the rule; don't add new ones).
- English identifiers; UI strings are Turkish literals used as keys in `Timelapse/Localizable.xcstrings` (12 languages: tr source + ar de en es fr hi ja ko pt ru zh-Hans).
- **Every new user-facing string needs translations added to the xcstrings** — the owner checks and complains about untranslated text. Pattern used: a Python script that inserts `localizations.<lang>.stringUnit` entries (see git history, commits touching Localizable.xcstrings). `String(localized:bundle:.appLanguage)` for strings in Swift code; plain `LocalizedStringKey` Text works too. Widget extension has NO string catalog — its strings are hardcoded Turkish (known gap; the expanded Dynamic Island text "Timelapse oluşturuluyor" stays Turkish).
- Owner sends screenshots/screen recordings as feedback and iterates in small batches. Build + run unit tests + **push to origin/main after every batch** (they install on device from this repo).

## What was done across this session (all pushed)

1. New 4-tab shell (`MainTabView.swift`): Home / Projects / Saved / Settings + center capture button in a **custom liquid glass tab bar** (drag-to-select capsule highlight, directional pane slide animation, re-selecting Projects pops to root via an `.id` reset token that bumps only on re-tap or 0.5s *after* leaving the tab — see pitfalls).
2. Background rendering (`TimelapseRenderService`) + **Live Activity/Dynamic Island** progress (real app icon asset left, progress ring right, alert expansion on finish). Unsaved finished renders show as rows in the Projects list only; Saved tab shows only actually-saved videos (`SavedTimelapse` model, `TimelapseLibrary`).
3. 7-day soft-delete trash for saved timelapses (projects keep 30 days) in Settings → Son Silinenler.
4. Home dashboard: time-aware greeting (4 windows incl. "İyi geceler"), activity grid, due-today rows (latest-photo thumbnails), tilted flashcard deck (stats + tips).
5. Growth features: day-numbered photo reminders, widget deep link `flapse://capture` (URL scheme registered in Info.plist, handled in `MainTabView.onOpenURL`), outro end-card with day count + "Made with Flapse" QR (`LegalLinks.appSite`), 9:16 `StoryShareCard`.
6. **Smart alignment is now FREE and default-on** (`smartAlignmentEnabled` AppStorage defaults true); only *manual* per-frame alignment is Pro. Paywall/Welcome/Settings copy updated to match. Do not reintroduce it as a Pro bullet.
7. Auto-capture flow (`AutoCaptureFlow`): classify immediately after shutter → recognized subject goes straight to a photo-backed confirmation (add / choose other / retake / cancel); unrecognized shows a review screen. **Never silently auto-assign** — the owner explicitly demanded confirmation always. Matcher (`ProjectMatcher`) scores projects by mean of top-3 nearest signature vectors.
8. Front camera photos un-mirrored (photo connection `isVideoMirrored = false` set in `CameraService.capturePhoto`).
9. Background render failure auto-retry: `TimelapseComposerError.writerFailed` (error 2) happens because iOS cuts the hardware encoder when the app suspends. `TimelapseExportViewModel` stores a `retryAction` + `failedInBackground`; `TimelapseRenderService` observes `didBecomeActiveNotification` and re-runs the export, keeping the Live Activity alive.
10. Performance: 120Hz via `CADisableMinimumFrameDurationOnPhone`, Metal-backed fire border (`drawingGroup`), and the big one — export sheet `frames` converted from a repeatedly-evaluated computed property (main-thread faulting of ALL photo data) to a once-loaded `@State` with per-item `Task.yield()`.
11. Publishing prep: `NSPhotoLibraryUsageDescription` added; privacy/support pages exist in `docs/` (EN+TR); README fully rewritten ("ghost alignment" wording is banned — it's "smart alignment" now).

## Session after handoff (2026-07-11/12, all pushed)

1. **Photos saving fixed everywhere** — new `PhotoLibrarySaver` (add-only PHPhotoLibrary authorization, `.photosDeniedAlert` view modifier with an "Ayarları Aç" action). Used by the export sheet, Saved context menu, and entry viewer. The old code never requested permission and swallowed failures.
2. **Export sheet state bug fixed**: opening a *finished* render used to show "Yeniden Oluştur" instead of the share/save/AI-caption actions, because setting `alignMode` in `.task` fired `onChange` → `isStale = true`. Alignment + finished-phase adoption now happen in `init` — keep it there; anything that mutates control state after appear will re-trigger the stale flag.
3. **Beat sync restored + loop fix**: the "drop-synced cuts" reallocation (from `e22ee93`) made manual songs cut off-beat and was removed (`alignedCutTimes`, `changeScores`, `AudioBeatAnalyzer.structure`/`dropTime` are gone). Cuts are strictly one per beat via `TimelapseExportViewModel.loopedCutTimes`, which repeats the beat grid shifted by the song duration when the video outlives the track (muxer loops audio from 0). 3 unit tests cover it. **Do not reintroduce drop detection without owner sign-off.**
4. **Camera prewarm**: `CameraService.shared` + `prewarm()` starts the session while the full-screen cover animates (tab-bar capture + quick-pick paths). `configure` early-returns when the input already matches. If a capture flow is cancelled before presenting (quick-pick dismissed, paywall), call `CameraService.shared.stop()` — otherwise the green camera indicator stays on (MainTabView.presentPendingCapture does this).
5. **Bug/security sweep fixes**: `LocationService` no longer leaks/hangs continuations on concurrent calls (pending ones are resumed before being replaced); CloudKit share upload deletes its temp JPEG assets after `modifyRecords`; `TimelapseRenderService` prunes finished jobs whose tmp video iOS purged (and `finishedJobs` re-checks file existence); `TimelapseLibrary.purgeExpired` also removes orphaned files in `SavedTimelapses/` not referenced by any model.
6. Sweep notes (reviewed, intentionally unchanged): no networking at all ("Data Not Collected" stays accurate; CaptionWriter is on-device FoundationModels); StoreKit entitlements are verified and never persisted; admin Pro rides UserDefaults/iCloud KVS by design; `CKShare.publicPermission = .readWrite` is required for the link-invite UX — anyone with the link can join and add photos, revisit before marketing the feature broadly.

## Release-readiness pass (2026-07-12, pushed)

1. App icon 1024px had an alpha channel (App Store Connect rejects it) — flattened onto opaque white in place.
2. Release build now has **zero warnings**: `Locale.Language.characterDirection` replaces deprecated API in `ContentView`, `AutoCaptureFlow.subjectLabel` no longer passes a main-actor method as a nonisolated closure, `TimelapseAudio.decodeSamples` is async via `loadTracks(withMediaType:)`.
3. `Widgets/PrivacyInfo.xcprivacy` added (UserDefaults CA92.1 + 1C8F.1); app manifest gained 1C8F.1 (app-group suite).
4. `LegalLinks` stale TODO doc comments removed; URLs are final (pending Pages enable).
5. `RELEASE_CHECKLIST.md` added — the full pre-submission list.
6. `.github/workflows/ci.yml` exists **locally only**: the git credential lacks `workflow` scope, so it's gitignored. To enable CI: remove `.github/workflows/` from `.gitignore` and push from a credential with workflow scope.

## Currently stuck / needs the owner

- **GitHub Pages is NOT enabled** — the harness blocked publishing a public site. Owner must run: `gh api repos/ozcanr17/Timelapse/pages -X POST -f "source[branch]=main" -f "source[path]=/docs"` (or repo Settings → Pages → main /docs). Until then `LegalLinks.privacyPolicy/support/appSite` URLs 404 and the outro QR points at a dead page.
- App Store Connect work (human-only): create IAP products (`com.ridvan.timelapse.pro.monthly/yearly/lifetime`), privacy questionnaire ("Data Not Collected" is accurate), screenshots, review notes. Sign in with Apple + CloudKit entitlements are wired but disabled (needs paid Apple dev account) — see `project_handoff.md`.

## Next plan (agreed with owner, not started)

- Verify on device: background-retry UX, QR scannability in the outro, Live Activity alert reliability.
- Possible next features from the agreed roadmap: streak freeze/repair, auto-captioned share templates as video (not just image), Watch complication, weight-loss / renovation / scenery categories (owner asked for category ideas; these were the top picks).
- Widget-extension localization catalog if the owner complains about Turkish in the island's expanded view.

## Pitfalls encountered — DO NOT repeat

1. **Liquid glass nesting**: a `glassEffect` view inside a `GlassEffectContainer` (or in a `.background` of another glass view) gets *merged/flattened* and looks solid. The working recipe for the tab bar: bar = `liquidGlassCapsule` on the icon row; selection capsule = `.overlay` ABOVE the bar glass; then a **duplicate non-hit-testing icon row overlaid on top** so the capsule's lens doesn't blur the icons. Don't "simplify" this structure.
2. **Live Activity images**: ActivityKit silently renders oversized images as a gray box. The widget logo asset (`Widgets/Assets.xcassets/AppLogo.imageset`) is downscaled to 128px on purpose. Don't replace with the 1024px icon. Also: the logo must be the actual `AppIcon.png` copy — hand-drawn SF-symbol approximations were rejected twice.
3. **`.id()` resets kill animations**: bumping the Projects pane reset token during tab switching made home→projects transition instant. The token bumps only on re-tap of Projects or ~0.5s after leaving it.
4. **Hardware video encoder dies in background** → `writerFailed`. Never "fix" by removing the background task; keep the retry-on-foreground mechanism. Don't promise unlimited background rendering.
5. **Main-thread SwiftData faulting**: computed properties in views that touch `entry.imageData` load full photo blobs synchronously and re-run every body pass. Always cache into `@State` (once) or go through `ImageDownsampler.cachedImage` (async). The export sheet was the offender; check any new view for this pattern.
6. **Toolbar buttons on iOS 26**: custom glass circles inside toolbar items fight the system's automatic glass grouping (ugly square press highlight / thin rectangle artifacts). Use plain 21pt icons in 30pt frames (see `ProjectDetailView.toolbarIcon`) and let the system provide the glass.
7. **Front camera mirroring** is fixed at the photo-output connection level — don't flip the image in post.
8. Widget/app can't share Swift files easily (separate `PBXFileSystemSynchronizedRootGroup`s): `RenderActivityAttributes` is **duplicated** in `Timelapse/Features/Export/RenderActivity.swift` and `Widgets/RenderLiveActivity.swift` — ActivityKit matches by type name, so keep the two structs byte-identical when changing.
9. QR in `TimelapseComposer` outro must be drawn via `UIImage(cgImage:).draw` (CGContext `ctx.draw` vertically mirrors it → unscannable).
10. The owner's monetization accuracy matters: if a feature's gating changes, update Paywall, Welcome, Settings, and README in the same commit.

## Key file map (new/heavily changed this session)

- `Timelapse/MainTabView.swift` — tab shell, glass bar, deep link handling, pane animation
- `Timelapse/Features/Home/HomeView.swift` — dashboard, flashcards, due rows
- `Timelapse/Features/Saved/SavedTimelapsesView.swift` + `Models/SavedTimelapse.swift` — library, soft delete
- `Timelapse/Features/Export/TimelapseRenderService.swift` — background jobs, retry, `TimelapseLibrary`
- `Timelapse/Features/Export/RenderActivity.swift` + `Widgets/RenderLiveActivity.swift` — Live Activity (duplicated attributes!)
- `Timelapse/Features/Export/TimelapseExportSheet.swift` — studio; `frames` is cached `@State`, red Cancel while rendering
- `Timelapse/Features/Export/TimelapseComposer.swift` — render pipeline, eased crossfade, outro + QR
- `Timelapse/Features/AutoSort/AutoCaptureFlow.swift` + `ProjectMatcher.swift` — confirm-always flow, top-3 matching
- `Timelapse/Features/ProjectDetail/StoryShareCard.swift` — 9:16 share card
- `Timelapse/Theme.swift` — `LiquidGlassStyle` (`clear:` variant, tint-over-material fallback), `glassIcon` button style
- `Widgets/FlapseWidgets.swift` — redesigned widgets, `WidgetBackground`, deep links
- `docs/` — GitHub Pages content (privacy/support/index)
