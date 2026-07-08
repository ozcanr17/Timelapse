# Flapse

> Capture the same subject one frame at a time and watch change unfold as a shareable timelapse video.

Flapse is a native iOS app for building day-by-day "progress" timelapses — beard growth, a child growing up, a plant, a fitness journey, a pet. You take one aligned photo per day (or on your own cadence), the app keeps you on streak, and turns your frames into a polished video.

- **Platform:** iOS 17.0+ (iPhone & iPad)
- **Stack:** Swift, SwiftUI, SwiftData, StoreKit 2, AVFoundation, CloudKit, AuthenticationServices — no third-party dependencies
- **Bundle ID:** `rozcan.Flapse` · **Version:** 1.0 (1)

## Why

A good progress timelapse needs two things people struggle to do by hand: **alignment** (every photo framed the same) and **consistency** (actually showing up every day). Flapse solves the first with a semi-transparent *ghost* of your previous shot overlaid on the live camera, and the second with per-project cadence, streaks, and reminder notifications.

## Features

- **Projects** — one per story (self, child, plant, pet, fitness…), each with its own cadence: daily, every other day, or weekly
- **Ghost-aligned camera** — previous frame overlaid for perfect framing; smart (Vision-based) and manual alignment for export
- **Timelapse export** — MP4 with adjustable speed, transitions, and date/note overlays; save to Photos or share
- **Photo import** — build a project from existing photos; EXIF dates order them automatically (Pro)
- **Capture Together** — invite someone to contribute to the same project via CloudKit sharing (Pro)
- **iCloud backup** — optional CloudKit sync of your library (Pro)
- **Activity view** — photo-filled contribution grid, streaks, and reminders to keep the habit going

## Monetization

Freemium: one project and 14 frames free; Flapse Pro (monthly subscription or lifetime unlock via StoreKit 2) removes limits and unlocks smart alignment, import, Capture Together, iCloud backup, and 4K watermark-free export.

## Development

Open `Timelapse.xcodeproj` in Xcode 16+, select the **Timelapse** scheme, and run. All business logic is unit-tested; run the full suite with:

```sh
xcodebuild -project Timelapse.xcodeproj -scheme Timelapse \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

The architecture is MVVM with a protocol-based service layer (`ProjectRepository`, `StoreService`, `CameraService`, `SharedProjectService`), so tests inject in-memory or fake implementations. UI tests launch with `--uitests` for a clean in-memory store.

Before shipping a build with sharing enabled, deploy the CloudKit schema to Production in the [CloudKit Console](https://icloud.developer.apple.com).

## Privacy

Photos stay on device unless iCloud backup or Capture Together is enabled. No analytics, no tracking, no third-party SDKs.
