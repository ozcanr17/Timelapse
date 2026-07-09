# Flapse

> Capture the same subject one frame at a time and watch change unfold as a shareable timelapse video.

Flapse is a native iOS app for building day-by-day "progress" timelapses — a beard, a child, a plant, a fitness journey, a pregnancy, a daily outfit. You take one aligned photo per day (or on your own cadence), the app keeps you on streak, and turns your frames into a polished, music-backed video.

- **Platform:** iOS 17.0+ (iPhone & iPad) · widget extension included
- **Stack:** Swift, SwiftUI, SwiftData, CloudKit, StoreKit 2, AVFoundation, Vision, WidgetKit, Apple Foundation Models — no third-party dependencies
- **Languages:** Turkish, English, German, Spanish, French, Portuguese, Hindi, Simplified Chinese, Japanese, Arabic, Russian, Korean — switchable in-app, live, no restart
- **Bundle ID:** `rozcan.Flapse` · **Version:** 1.0 (1)

---

## App Tour

### Welcome & first launch
A restrained onboarding screen introduces the core loop — ghost alignment, cadence reminders, one-tap timelapse — with a privacy note ("your photos stay on your device"). The app opens in the phone's system language automatically.

### Home — Projects
The home screen is a photo-first list:

- **Activity hero card** — a GitHub-style contribution grid where every square is that day's actual photo, plus total frame count and today's to-do state.
- **Project cards** — each project is a full-bleed photo card showing its latest frame, title, frame count, and cadence. Projects with an active day streak get an **animated fire border** burning around the card edge.
- **Toolbar** — Settings, *create project from Photos* (bulk import), and *new project*.
- **Capture button** — the main CTA. Free users pick a project; Pro users go straight to the camera with **auto-sorting**.

Creating a project requires **Sign in with Apple** (a friendly gate sheet explains that projects link to the account and return on any device).

### Camera — ghost-aligned capture
The capture screen overlays your **previous frame as a translucent ghost** so every photo lines up. Couple-mode projects show a split guide for two people. Location (optional) tags each frame with the place it was taken. After a capture, milestone toasts celebrate round numbers ("100. kare! 🎉", "30 gün seri! 🔥").

**Auto-sorting (Pro):** shoot from the home screen without picking a project — Vision classifies the subject (face-crop signatures make selfies match reliably), proposes the matching project, and asks for confirmation; or you pick / create a project via the full form.

### Project detail
A hero image, stats (total frames, day streak, days running), collaborator names for shared projects, and a timeline of every frame with month filters. Toolbar: **share** (choose *Streak Card* or *Before & After card* — Day 1 vs Today with the day count), **edit project** (name, category, cadence), **add photos** (bulk import with EXIF date ordering), and **Capture Together invite**.

Free tier: 1 project, 14 frames; lapsed subscribers keep their newest project with the latest 14 frames visible, the rest locked behind the paywall.

### Timelapse Studio (export)
Tap *Create Timelapse* and the studio opens with a live preview that resizes to your chosen aspect ratio:

| Control | Options |
|---|---|
| **Speed** | slider 0.25×–3× |
| **Zoom** | slider 0.5×–2×, scaled around center |
| **Aspect** | 3:4 · 9:16 · 9:18 · 1:1 · 4:3 · 16:9 |
| **Music** | off · 5 bundled royalty-free moods (Calm, Joyful, Upbeat, Melancholic, Cinematic) · any audio file from Files (Pro) |
| **Beat sync** | photo cuts land exactly on the beat; bundled tracks use exact grids, imported songs use onset detection with tempo-estimation fallback; **drop detection** places your biggest visual change on the chorus hit |
| **Transition** | cut · crossfade · **Fluid (AI)** — Vision optical-flow morphing that warps faces and scenes between frames (motion-compensated dissolve fallback where the flow engine is unavailable) |
| **Alignment** | off · **Smart** (eye-locked face tracking, torso pose for fitness/outfit, belly for pregnancy, group for couples, saliency fallback) · **Manual per-photo** — page through every frame, drag / pinch-zoom / two-finger-rotate each one, or Apply to All |
| **Overlays** | date stamp, custom note, corner positions; free tier carries the FLAPSE mark |

Aspect-ratio bars are filled with a **content-aware mirrored edge extension** (never black bars). Every video ends with a 3-second outro replicating the app's launch animation — the last frame dissolves into the theme background while the logo spins in.

After rendering: share, save to Photos, and (on Apple Intelligence devices) an **on-device AI caption** ready to copy.

### Capture Together (Pro)
Invite anyone by link: the share sheet sends a localized invitation message plus an iCloud link. The invitee taps it, the shared project downloads **with all previous photos**, and both people contribute frames to the same story. Storage lives in the owner's iCloud; nothing touches third-party servers.

### Recently Deleted
Deleted projects rest in a Settings trash for 30 days (synced to iCloud when backup is on) with per-item restore or immediate permanent deletion.

### Settings
Membership (paywall/restore) · Account (Sign in with Apple) · Pro feature toggles · **iCloud Status panel** (sign-in, iCloud account, backup, cloud-vs-local store — green/orange dots) · Theme gallery (7 themes) · **App language picker** (globe icon, instant switch) · Recently Deleted · reminders with hour picker · stats · welcome replay · camera permissions.

### Widgets (all 2×2)
1. **Streak** — flame, day count, today's capture status
2. **Activity** — 6×6 photo grid of the last 5 weeks
3. **Projects** — latest covers of up to 4 projects; empty slots become streak/status tiles

### Monetization
Freemium. **Flapse Pro** — monthly ($0.99), yearly ($9.99, best value), both with a **7-day free trial**, or lifetime ($19.99) — unlocks unlimited projects/frames, smart & per-photo alignment, fluid AI transitions, music & beat sync, Capture Together, iCloud backup, auto-sorting, unlimited import, and watermark-free 4K export. Prices come from App Store Connect (Turkey overrides: 50₺ / 500₺ / 1000₺).

---

## Development

Open `Timelapse.xcodeproj` (Xcode 16+), scheme **Timelapse**. StoreKit testing is preconfigured via `Products.storekit`.

```sh
xcodebuild -project Timelapse.xcodeproj -scheme Timelapse \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Architecture: MVVM with protocol-based services (`ProjectRepository`, `StoreService`, `CameraService`, `SharedProjectService`, `TimelapseComposer`); tests inject fakes/in-memory stores; UI tests launch with `--uitests -auth.appleUserID …` for clean state. Rendering-quality changes are guarded by **pixel-level tests** that decode real exported videos.

Before shipping builds with sharing/backup: deploy the CloudKit schema to Production in the [CloudKit Console](https://icloud.developer.apple.com). App Store listing copy lives in [`docs/AppStoreListing.md`](docs/AppStoreListing.md).

## Privacy

Photos stay on device unless the user enables iCloud backup or Capture Together (both Apple iCloud, user's own account). No analytics, no tracking, no third-party SDKs. AI captions run entirely on-device.
