# HANDOFF — Flapse iOS App

Last updated: **2026-07-21**. This document is written for a completely new session with no prior context.

Read this file first, then:

1. `README.md` for the feature overview.
2. `YAYINLAMA_REHBERI.md` for the Turkish App Store publishing guide and live checklist.
3. `project_handoff.md` for older architectural and repository conventions.

## Project identity

Flapse is a native SwiftUI iOS app for building long-term photo progress projects and creating timelapse videos. It uses SwiftData, CloudKit, StoreKit 2, AVFoundation, Vision, ActivityKit and WidgetKit. There are no third-party runtime dependencies.

- Actual local repository: `/Users/ridvanozcan/Desktop/workspace/Flapse`
- Old/stale path sometimes supplied by the environment: `/Users/ridvanozcan/Desktop/workspace/Timelapse`
- GitHub: `https://github.com/ozcanr17/Flapse.git`
- Branch: `main`
- Latest pushed code commit: `55a8382 Restore tinted liquid glass and directional tab motion`
- App display name: **Flapse**
- Main bundle ID: `rozcan.Flapse`
- Widget bundle ID: `rozcan.Flapse.Widgets`
- Apple team: `5ZYCHZ39QV`
- Minimum iOS: 17; current development/testing also targets iOS 26.

Always confirm the working directory before running Git or Xcode commands. The `Timelapse` directory is not the active Git repository.

## Current task

The active work is a performance and interaction-latency stabilization pass, followed by restoration of the owner's preferred Liquid Glass tab bar.

The owner expects:

- Tab changes, navigation and ordinary taps to acknowledge input immediately, with a perceived response budget near 100 ms.
- Large projects and photo-heavy screens not to block the main thread or grow memory without bound.
- No loss of existing features, navigation state, data integrity or image quality.
- The custom five-item bottom bar to retain the preferred iOS 26 Liquid Glass appearance.
- Tab content to move horizontally by direction: when selecting a tab to the left, the incoming view moves left into place; when selecting a tab to the right, it moves right into place.

The 100 ms target applies to visible acknowledgement of input. Disk reads, CloudKit sync, photo import and video export cannot be guaranteed to finish within 100 ms; those operations must acknowledge immediately and continue asynchronously.

## What has been completed

### Performance and crash stabilization

Recent commits, all pushed to `origin/main`:

- `7d164f6 Optimize media sync and navigation performance`
- `bff6d8d Prevent media sync memory spikes and tab crashes`
- `3af4684 Reduce interaction latency and restore native glass`
- `55a8382 Restore tinted liquid glass and directional tab motion`

Key changes:

- Removed broad root-level SwiftData queries that caused unrelated tabs to invalidate and redraw when project or photo records changed.
- Reduced repeated sorting/filtering in Home rows. Latest-entry lookup is now a single lazy filter/max pass instead of repeated `sortedEntries` construction in `body` and thumbnail tasks.
- Fixed a major thumbnail pipeline bottleneck: SwiftData `.externalStorage` image data is no longer faulted eagerly for every visible cell before concurrency control. A decode slot is acquired first, then the data is loaded on the model actor, and downsampling runs detached. At most three image data loads/decodes proceed concurrently.
- Originals remain untouched. UI thumbnails use bounded, memory-costed downsampling and revision-based cache keys.
- CloudKit/shared-project media synchronization was changed to avoid loading every full-resolution photo into memory at once. Media is processed incrementally and in bounded batches.
- Removed a duplicated, non-hit-testing copy of the entire tab-bar icon row. It was doubling layout/render work.
- Replaced long tab highlight springs with an 80 ms selection animation and a short interactive drag spring.
- Reduced the deliberate context-menu action delay from 220 ms to 32 ms, preserving the menu-dismissal race workaround without making taps feel ignored.
- Preserved cancellation/generation checks during rapid tab switching so an older animation cannot overwrite a newer selection.

Earlier crash root causes that must stay fixed:

- Duplicate CloudKit record IDs were passed into a dictionary, causing `Fatal error: Duplicate values for key`. Shared-record collections must be deduplicated by stable record ID before dictionary creation.
- Duplicate SwiftUI identities appeared in `ForEach<Array<Entry>, UUID, ...>`. Collections shown by SwiftUI must have stable, unique IDs and shared-project imports must not create duplicate local entries.
- Large CloudKit/photo batches previously caused CPU and memory spikes; an earlier physical-device report showed roughly 86% average CPU and 1.38 GB peak memory. Do not return to all-at-once media loading.

### Liquid Glass and directional tab motion

The current implementation is in `Flapse/MainTabView.swift` and `Flapse/Theme.swift`.

- The bar uses the earlier visual recipe: native iOS 26 `glassEffect`, capsule clipping, interactivity, and a subtle adaptive tint (`F5F5F7` light / `1B1B1F` dark at 0.26 opacity).
- A restrained highlight remains above the glass. The duplicate icon overlay and slow spring were intentionally not restored.
- Tab content keeps the native `TabView`; it is not replaced by a conditional custom ZStack. This preserves each tab's `NavigationStack` and avoids rebuilding expensive screens.
- On selection, the new tab starts 32 points from the opposite side and settles in 160 ms with a slight opacity change. The tab state changes immediately.
- Rapid repeated selections are protected by `contentTransitionGeneration`.
- Reduce Motion disables the horizontal transition.
- Re-tapping Projects still clears `projectsPath` as before.

### Validation completed

- Generic iOS Simulator Debug build: passed after the latest glass/transition changes.
- Physical iPhone Debug build: passed after the latest changes.
- Latest build was installed on device ID `68A160A9-06E1-5973-8014-EB9128274414` (`rozcan.Flapse`).
- `testRapidTabNavigationRemainsResponsive`: passed with 12 consecutive transitions, no crash. Latest measurement average: **8.721 s** with values `8.688253`, `8.771921`, `8.702762`.
- Previous comparable measurement before directional motion: **8.878 s**. The motion did not regress the test.
- The absolute UI-test duration is not app tap latency: the test performs repeated `waitForExistence`/XCUITest quiescence waits of about one second per step. Use it for regression/crash detection, not as a 100 ms latency measurement.
- The unit suite had **153 passing tests** after the media/performance changes. The final one-line glass restoration and directional tab change were subsequently verified by builds and the focused rapid-tab UI test.

The latest UI test result bundle is:

`/Users/ridvanozcan/Library/Developer/Xcode/DerivedData/Flapse-fzsukklxtjzjhmchajrzzqjxnkgf/Logs/Test/Test-Flapse-2026.07.21_00-05-47-+0300.xcresult`

## Current status and what is not yet proven

There is no active compilation failure or known reproducible crash in the current build.

The most recent physical-device run did not produce a new Flapse `.ips`, Jetsam/OOM, hang or resource-termination report. Xcode console stdout from a detached/finished run is not retained as a durable log, so the remaining perceived slowness has not yet been tied to a fresh Time Profiler trace from the owner's exact device interaction.

The code-level bottlenecks found so far were fixed, and automated tab switching is stable. The remaining question is whether the owner still perceives a delay on the newly installed build and, if so, which exact screen/action causes it.

## Next plan

1. Have the owner test commit `55a8382` on the physical phone, especially Home → Projects → Saved → Settings and opening a photo-heavy project.
2. If latency remains, record the exact interaction with Instruments on the physical device:
   - Time Profiler with thread state and Swift concurrency enabled.
   - SwiftUI Instruments for body evaluations and long view updates.
   - Core Animation for hitches/FPS.
   - Allocations for repeated tab loops and project open/close loops.
3. Add `os_signpost` intervals around tab selection, first rendered frame, project fetch completion and thumbnail availability if Instruments cannot attribute the delay clearly. Do not add arbitrary sleeps/debounces.
4. Compare tap-to-first-frame, main-thread tasks over 16.7 ms, peak memory and surviving objects across at least 20 tab loops.
5. Only then change the next proven hotspot. Keep each change isolated and reversible.
6. Run the 153 unit tests, the focused rapid-tab UI test, a physical-device build, and install the build before handoff.

## Important working-tree state

At this handoff, these unrelated owner-owned changes are intentionally not staged or committed:

- `Flapse/InfoPlist.xcstrings`
- `Flapse/Localizable.xcstrings`
- `Widgets/Localizable.xcstrings`
- `.agents/` (untracked)
- `.codex/` (untracked)

Do not discard, overwrite, normalize, stage or include them in an unrelated commit. Always stage explicit file paths.

## Pitfalls encountered — do not repeat

1. **Do not use the stale `Timelapse` folder.** The active repository is `/Users/ridvanozcan/Desktop/workspace/Flapse`.
2. **Do not restore the duplicate tab icon row.** Old handoff text said to preserve it, but profiling/code inspection showed that it duplicated layout and rendering. The bar must contain one interactive icon row only.
3. **Do not restore the 0.4-second spring or 220 ms menu delay.** They were directly visible as sluggish interaction.
4. **Do not rebuild all tab views conditionally to get slide animations.** That loses navigation state and re-triggers expensive lifecycle work. The current implementation animates the retained native `TabView` container.
5. **Do not load `entry.imageData` in `body`, sorting/filtering computed properties, or before the thumbnail concurrency slot.** SwiftData external-storage faults can synchronously pull large compressed photos onto the main actor.
6. **Do not load all CloudKit/shared-project images into arrays or dictionaries at once.** Process IDs first, deduplicate, then fetch/upload media in bounded batches.
7. **Do not build dictionaries from CloudKit records without deduplicating record IDs.** This caused the fatal duplicate-key crash.
8. **Do not use unstable or duplicate SwiftUI IDs.** Never paper over duplicate entries by switching to array indices; repair the underlying data/import deduplication.
9. **Do not claim every operation finishes under 100 ms.** Guarantee immediate visual feedback; move unavoidable work off the animation-critical path.
10. **Do not add random delays, blanket `DispatchQueue.main.async`, or broad `@MainActor` annotations to hide races.** Measure and fix ownership/isolation.
11. **Do not lower original photo quality.** Downsample only presentation thumbnails; editing/export must use originals.
12. **Do not remove the foreground render retry.** iOS can kill the hardware encoder in background; `writerFailed` retry on foreground is required.
13. **Do not change front-camera mirroring casually.** Preview and captured selfie are explicitly mirrored to match what the user sees; the back camera remains unmirrored.
14. **Do not use nested-sheet `dismiss` after PhotosPicker.** Dismiss import through the presenter's item binding (`onFinished` → `activeSheet = nil`).
15. **Do not reintroduce removed marketing claims or gates.** Drop detection was removed; smart alignment is free/default-on; auto-sort requires confirmation.
16. **Do not re-add flat `docs/privacy.html` or `docs/support.html`.** GitHub Pages would shadow the intended directory index pages.
17. **Do not add new user-facing strings without all catalog localizations.** App and widget catalogs cover Turkish source plus ar, de, en, es, fr, hi, ja, ko, pt, ru and zh-Hans.
18. **Do not commit unrelated localization or agent metadata changes.** The current dirty files listed above belong to the owner/current environment.

## Project conventions

- Prefer small, measurable changes within the current architecture.
- Preserve all existing features, UI workflows and data semantics.
- Keep English identifiers. Turkish UI literals act as localization keys.
- Do not add code comments unless the owner explicitly changes the existing repository rule. Some comments predate this rule; avoid expanding them.
- Build and test with Xcode's command line. SourceKit's `No such module UIKit` diagnostics in non-Xcode harnesses are noise.
- Use the iOS 26.5 `iPhone 17 Pro` simulator UUID `C85B1445-BFF2-40AC-B7FD-95A9C374AFA8` when it is available, or resolve a unique simulator before running.
- Push completed, verified batches to `origin/main`.

## Build and test commands

```sh
cd /Users/ridvanozcan/Desktop/workspace/Flapse
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

xcodebuild -project Flapse.xcodeproj -scheme Flapse -configuration Debug \
  -destination 'generic/platform=iOS Simulator' build

xcodebuild test -project Flapse.xcodeproj -scheme Flapse \
  -destination 'platform=iOS Simulator,id=C85B1445-BFF2-40AC-B7FD-95A9C374AFA8' \
  -only-testing:FlapseTests

xcodebuild test -project Flapse.xcodeproj -scheme Flapse \
  -destination 'platform=iOS Simulator,id=C85B1445-BFF2-40AC-B7FD-95A9C374AFA8' \
  -only-testing:FlapseUITests/FlapseUITests/testRapidTabNavigationRemainsResponsive
```

Physical device currently used:

```sh
xcodebuild -project Flapse.xcodeproj -scheme Flapse -configuration Debug \
  -destination 'id=68A160A9-06E1-5973-8014-EB9128274414' build

xcrun devicectl device install app \
  --device 68A160A9-06E1-5973-8014-EB9128274414 \
  /Users/ridvanozcan/Library/Developer/Xcode/DerivedData/Flapse-fzsukklxtjzjhmchajrzzqjxnkgf/Build/Products/Debug-iphoneos/Flapse.app
```

## App Store publishing status

The technical signing/export path was previously verified end-to-end: archive, provisioning, entitlements and App Store `.ipa` export succeeded. GitHub Pages privacy/support pages are live. The remaining publishing work is primarily App Store Connect setup by the owner:

1. Complete Paid Applications agreement, banking and tax.
2. Create the app record and IAPs.
3. Paste metadata from `docs/AppStoreListing.md`, upload screenshots and promote CloudKit schema to Production.
4. Upload through Organizer/TestFlight and submit.

Current product IDs intentionally retain the old domain and must not be renamed:

- `com.ridvan.timelapse.pro.monthly`
- `com.ridvan.timelapse.pro.yearly`
- `com.ridvan.timelapse.pro.lifetime`

See `YAYINLAMA_REHBERI.md` before changing publishing configuration.

## Key file map

- `Flapse/MainTabView.swift` — retained native tab shell, custom Liquid Glass bar, directional content motion and capture deep link.
- `Flapse/Theme.swift` — theme palettes and shared Liquid Glass modifiers.
- `Flapse/ImageDownsampler.swift` — bounded image loading/decoding and thumbnail cache.
- `Flapse/Features/Home/HomeView.swift` — Home queries/cards and thumbnail consumers.
- `Flapse/Features/ProjectDetail/ProjectDetailView.swift` — paginated/lazy project timeline.
- `Flapse/Features/ProjectDetail/EntryViewerView.swift` — stable full-screen photo paging and metadata actions.
- `Flapse/Features/ProjectDetail/PhotoCropView.swift` — crop/flip/rotate editor using original-resolution output.
- `Flapse/Features/CaptureTogether/SharedProjectService.swift` — CloudKit shared-project synchronization and deduplication.
- `Flapse/Features/Export/TimelapseRenderService.swift` — render jobs, background handling and foreground retry.
- `Flapse/Features/Export/TimelapseComposer.swift` — video assembly, transitions, music timing and outro.
- `Flapse/Features/Import/PhotoImportSheet.swift` and `PhotoImportViewModel.swift` — Photos import and rollback behavior.
- `Flapse/Features/Settings/RecentlyDeletedView.swift` — authenticated/grouped deletion recovery.
- `Widgets/FlapseWidgets.swift` — Home/Lock Screen widgets.
- `docs/AppStoreListing.md`, `YAYINLAMA_REHBERI.md`, `RELEASE_CHECKLIST.md`, `ExportOptions.plist`, `Products.storekit` — publishing material.

## Final note for the next session

Start by running `git status`, confirming `origin/main` and reading the latest user report. Do not redo completed optimizations or reset the working tree. The next useful work is evidence-driven physical-device profiling if the owner still reports slowness on commit `55a8382`.
