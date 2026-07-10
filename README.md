# Flapse

> Capture the same subject one frame at a time and watch change unfold as a shareable timelapse video.

Flapse is a native iOS app for building day-by-day "progress" timelapses — a beard, a child, a person, a plant, a fitness journey, a pregnancy, a daily outfit. You take one aligned photo per day (or on your own cadence), the app keeps you on streak, and turns your frames into a polished, music-backed video.

- **Platform:** iOS 17.0+ (iPhone & iPad) · widget extension + Live Activity included
- **Stack:** Swift, SwiftUI, SwiftData, CloudKit, StoreKit 2, AVFoundation, Vision, WidgetKit, ActivityKit, Apple Foundation Models — no third-party dependencies
- **Languages:** Turkish, English, German, Spanish, French, Portuguese, Hindi, Simplified Chinese, Japanese, Arabic, Russian, Korean — switchable in-app, live, no restart
- **Bundle ID:** `rozcan.Timelapse` · **Version:** 1.0 (1)

---

## App Tour

### Welcome & first launch
A restrained onboarding screen introduces the core loop — smart alignment, cadence reminders, one-tap timelapse — with a privacy note ("your photos stay on your device"). The app opens in the phone's system language automatically, and ProMotion displays run the full 120 Hz.

### Navigation — floating liquid glass tab bar
Four tabs (Home, Projects, Saved, Settings) plus a center capture button live in a custom **liquid glass** bar: a translucent capsule highlight slides between tabs, you can drag along the bar to scrub tabs, views slide in the direction of travel, and re-selecting Projects always pops back to the list.

### Home — daily dashboard
- **Time-aware greeting** (good morning / afternoon / evening / night) with today's date.
- **Activity hero card** — a GitHub-style contribution grid where every square is that day's actual photo, plus total frame count and today's to-do state.
- **"Time to shoot today"** — quick rows for every project whose capture is due.
- **Flashcard deck** — tilted, wallet-pass-style cards with live stats (active projects, total frames, longest streak, this week) and capture tips.
- **Recent frames** — horizontally scrolling strip of the latest photos.

### Projects
Each project is a full-bleed photo card showing its latest frame, title, frame count, and cadence. Projects with an active day streak get an **animated fire border** burning around the card edge. In-progress and finished (unsaved) timelapse renders appear at the top of the same list; an unsaved render stays until you open and check it. Toolbar: *create project from Photos* (bulk import) and *new project*.

Creating a project requires **Sign in with Apple** (a friendly gate sheet explains that projects link to the account and return on any device).

**Categories:** Me, Person, Child, Plant, Hair & Beard, Pet, Fitness, Pregnancy, Baby, Outfit, Couple Mode (Pro), Other — each with its own accent color and icon.

### Camera — smart-aligned capture
The capture screen overlays your **previous frame as a translucent guide** so every photo lines up. Couple-mode projects show a split guide for two people. Location (optional) tags each frame with the place it was taken. After a capture, milestone toasts celebrate round numbers ("100. kare! 🎉", "30 gün seri! 🔥").

**Auto-sorting (Pro):** shoot from the tab bar without picking a project. After the shutter you first **review the photo** (use / retake / cancel). Vision then classifies the subject — face-crop signatures learn from a project's previous photos (top-3 nearest matching) so recognition sharpens over time — and **always asks for confirmation** with the photo attached: add to the suggested project, or pick/create another.

### Project detail
A hero image, stats (total frames, day streak, days running), collaborator names for shared projects, and a timeline of every frame with month filters. Opened photos support **pinch-to-zoom, pan, and double-tap zoom**. Toolbar: **share** (choose *Streak Card*, *Before & After card*, or a **9:16 Story Card** sized for Reels/TikTok — Day 1 on top, today below, day-count badge in the middle), **edit project**, **add photos** (bulk import with EXIF date ordering), and **Capture Together invite**.

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
| **Transition** | cut · smooth eased crossfade · **Fluid (AI, Pro)** — Vision optical-flow morphing that warps faces and scenes between frames |
| **Alignment** | **Smart is on by default for everyone** (eye-locked face tracking, torso pose for fitness/outfit, belly for pregnancy, group for couples, saliency fallback) · off · **Manual per-photo (Pro)** — page through every frame, drag / pinch-zoom / two-finger-rotate each one, or Apply to All |
| **Overlays** | date stamp, custom note, corner positions; free tier carries the FLAPSE mark |

Aspect-ratio bars are filled with a **content-aware mirrored edge extension** (never black bars). Every video ends with a 3-second outro replicating the launch animation, now with the journey length ("90 days of change") and a **"Made with Flapse" QR end-card** linking to the app site.

**Background rendering + Dynamic Island:** rendering continues if you leave the screen or the app. A **Live Activity** shows the real app logo on the island's left and a progress ring on the right; when the video is ready the island expands with a "Timelapse ready" alert. Renders also appear as tappable rows in Projects and Saved.

After rendering: share, save to Photos, **save in-app to the Saved library**, and (on Apple Intelligence devices) an **on-device AI caption** ready to copy.

### Saved — in-app video library
Finished timelapses can be stored inside the app: a poster grid with durations, full-screen playback (AVPlayerViewController with native fullscreen), share / save-to-Photos / delete via context menu. In-progress renders and ready-but-unsaved videos are listed at the top so nothing gets lost.

### Capture Together (Pro)
Invite anyone by link: the share sheet sends a localized invitation message plus an iCloud link. The invitee taps it, the shared project downloads **with all previous photos**, and both people contribute frames to the same story. Storage lives in the owner's iCloud; nothing touches third-party servers.

### Recently Deleted
Deleted projects rest in a Settings trash for 30 days; deleted saved timelapses for **7 days** — both with per-item restore or immediate permanent deletion.

### Settings
Membership (paywall/restore) · Account (Sign in with Apple) · feature toggles (smart alignment default, iCloud backup) · **iCloud Status panel** (sign-in, iCloud account, backup, cloud-vs-local store — green/orange dots) · Theme gallery (7 themes) · **App language picker** (globe icon, instant switch) · Recently Deleted · reminders with hour picker · stats · welcome replay · camera permissions.

### Notifications & reminders
Daily reminders arrive **with yesterday's photo attached** and a day-numbered title ("Day 41 — keep going"), scheduled per project cadence at your chosen hour.

### Widgets (all 2×2)
1. **Streak** — gradient flame, bold day counter, today's capture status chip
2. **Activity** — 6×6 photo grid of the last 5 weeks
3. **Projects** — latest covers of up to 4 projects; empty slots become streak/status tiles

All widgets share a modern dark-gradient look with a brand-green glow, and **tapping any widget deep-links straight into the camera** for today's due project (`flapse://capture`).

### Monetization
Freemium. **Flapse Pro** — monthly ($0.99), yearly ($9.99, best value), both with a **7-day free trial**, or lifetime ($19.99) — unlocks unlimited projects/frames, manual per-photo alignment, fluid AI transitions, music & beat sync, Capture Together, iCloud backup, auto-sorting, unlimited import, and watermark-free 4K export. Smart alignment is free for everyone. Prices come from App Store Connect (Turkey overrides: 50₺ / 500₺ / 1000₺).

---

## Development

Open `Timelapse.xcodeproj` (Xcode 16+), scheme **Timelapse**. StoreKit testing is preconfigured via `Products.storekit`.

```sh
xcodebuild -project Timelapse.xcodeproj -scheme Timelapse \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Architecture: MVVM with protocol-based services (`ProjectRepository`, `StoreService`, `CameraService`, `SharedProjectService`, `TimelapseComposer`); tests inject fakes/in-memory stores; UI tests launch with `--uitests -auth.appleUserID …` for clean state. Rendering-quality changes are guarded by **pixel-level tests** that decode real exported videos.

Before shipping builds with sharing/backup: deploy the CloudKit schema to Production in the [CloudKit Console](https://icloud.developer.apple.com). App Store listing copy lives in [`docs/AppStoreListing.md`](docs/AppStoreListing.md). Privacy & support pages live in [`docs/`](docs/) (GitHub Pages).

## Privacy

Photos stay on device unless the user enables iCloud backup or Capture Together (both Apple iCloud, user's own account). No analytics, no tracking, no third-party SDKs. AI captions and subject recognition run entirely on-device.
