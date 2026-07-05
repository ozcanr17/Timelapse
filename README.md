# Timelapse

> Capture the same subject one frame at a time and watch change unfold as a shareable timelapse video.

Timelapse is a native iOS app (Swift + SwiftUI) for building day-by-day “progress” timelapses — beard growth, a child growing up, a plant, a fitness journey, a pet. You take one aligned photo per day (or on your own cadence), the app keeps you on streak, and turns your frames into a polished video with optional date/note/branding overlays.

- **Platform:** iOS 17.0+ (iPhone & iPad)
- **Stack:** Swift 5, SwiftUI, SwiftData, StoreKit 2, AVFoundation, CloudKit (optional), AuthenticationServices
- **Dependencies:** None (100% first-party Apple frameworks)
- **Monetization:** Freemium + auto-renewable subscription and a one-time unlock
- **Bundle ID:** `rozcan.Timelapse` · **Version:** 1.0 (1)

---

## 1. App Purpose & Vision

### The problem
People want to document gradual physical change (a beard, a baby, weight loss, a growing plant) but end up with a messy camera roll of misaligned, hard-to-find photos and never turn them into anything. Consistency and alignment are the two things that make a good progress timelapse — and both are hard to do by hand.

### What the app does
Timelapse gives each “story” its own project and solves the two hard problems:

1. **Alignment** — a semi-transparent *ghost* of your previous shot is overlaid on the live camera so every photo lines up.
2. **Consistency** — per-project cadence (daily / every other day / weekly), a streak counter, and local reminders keep you coming back.

When you have enough frames, one tap renders an MP4 timelapse you can share, with adjustable speed and optional date/note/app-mark overlays.

### Target audience
Everyday consumers documenting a personal transformation: self-portrait / hair & beard, parents tracking a child, plant & pet owners, fitness and skincare journeys. No photography or editing skill required.

### Vision
Be the simplest, most delightful “one photo a day” app on iOS — private by default (your photos never leave your device unless you opt into iCloud), beautiful, and habit-forming.

---

## 2. Architecture & System Design

### High-level pattern: MVVM + protocol-oriented services

The app is **MVVM** with a thin service layer, chosen so that all business rules and side-effecting systems (persistence, StoreKit, camera, notifications) sit behind protocols and can be unit-tested without the real frameworks.

```
┌────────────────────────────────────────────────────────────┐
│  SwiftUI Views  (ProjectListView, CameraCaptureView, …)     │
│  - declarative, stateless where possible                    │
└───────────────┬────────────────────────────────────────────┘
                │ @Observable view models / @Environment
┌───────────────▼────────────────────────────────────────────┐
│  View Models  (@Observable, @MainActor)                     │
│  CameraCaptureViewModel · TimelapseExportViewModel ·        │
│  PaywallViewModel · AddProjectViewModel                     │
└───────────────┬────────────────────────────────────────────┘
                │ depend on PROTOCOLS, injected
┌───────────────▼────────────────────────────────────────────┐
│  Services (protocol-backed, swappable with fakes in tests)  │
│  ProjectRepository · StoreService · CameraService ·         │
│  TimelapseComposer · AuthService · ReminderScheduler        │
└───────────────┬────────────────────────────────────────────┘
                │
┌───────────────▼────────────────────────────────────────────┐
│  Apple frameworks: SwiftData · StoreKit 2 · AVFoundation ·  │
│  CloudKit · UserNotifications · AuthenticationServices      │
└────────────────────────────────────────────────────────────┘
```

### State management
- **`@Observable`** (Observation framework, iOS 17) for view models and `StoreService`.
- **`@Environment`** to inject `StoreService` and the theme palette app-wide.
- **`@State` / `@Bindable`** for local view state; **`@AppStorage`** for user preferences (theme, reminders, Pro feature toggles).
- **`@Query`** (SwiftData) for reactive lists of `Project`s.

### Persistence: SwiftData (+ optional CloudKit)
- Models: `Project` (1‑to‑many) → `Entry`. Defined in `Models/CoreModels.swift`.
- Photos are stored with `@Attribute(.externalStorage)` so large image blobs live outside the SQLite store (and become `CKAsset`s if iCloud sync is on).
- `Persistence/AppModelContainer.swift` builds the container. It is **local-only by default** and upgrades to CloudKit **only when the user opts into iCloud backup** (a Pro feature). If CloudKit is unavailable it safely falls back to local storage. Tests and previews use a dedicated in-memory container.
- All persistence goes through `ProjectRepository` (protocol `ProjectRepositoryProtocol`), never SwiftData directly from views.

### Monetization core: `FeatureGate` + `StoreService`
- `FeatureGate` is a **pure, testable** enum holding every monetization rule (free limits, which features are Pro). No StoreKit or UI inside it.
- `StoreService` wraps StoreKit 2 (`Product`, `Transaction.currentEntitlements`, `Transaction.updates`) and exposes a single source of truth: `isPro`.

### Rendering: `TimelapseComposer`
- `AVAssetWriter`-based frame-by-frame H.264 encoder (`Features/Export/TimelapseComposer.swift`), run off the main thread via `Task.detached`.
- Draws per-frame overlays (date, note, app mark) with `UIGraphicsImageRenderer` at the chosen corner.
- Fully decoupled behind `TimelapseComposing`, so `TimelapseExportViewModel` is tested with a fake composer.

### Design system
- `Theme.swift` centralizes typography, spacing, corner radii, semantic colors, category accents, and reusable button styles (`.timelapsePrimary`) and `.cardStyle()`. Multiple selectable palettes (film negative, light, cyber, etc.) via `AppTheme`, injected through `@Environment(\.theme)` and switchable at runtime.
- UI/UX philosophy: a “contact-sheet / film-stamp” aesthetic (monospaced numerals for dates & counts), large tappable targets, haptics on capture, light/dark aware.

### Folder structure
```
Timelapse/
├── TimelapseApp.swift            App entry, container + StoreService wiring
├── ContentView.swift             Root nav, splash, first-run welcome
├── Theme.swift, LogoMark.swift   Design system
├── LegalLinks.swift              Terms/Privacy/Support URLs (App Store required)
├── PrivacyInfo.xcprivacy         Privacy manifest (required-reason APIs)
├── Models/CoreModels.swift       @Model Project & Entry
├── Persistence/                  ModelContainer factories
├── Data/ProjectRepository.swift  Persistence gateway (protocol)
└── Features/
    ├── Projects/                 List, add-project, activity summary
    ├── ProjectDetail/            Detail, entry grid, streak share card
    ├── Camera/                   Capture, ghost alignment, camera service
    ├── Export/                   Composer, export sheet + view model
    ├── Store/                    StoreService, FeatureGate, Paywall
    ├── Auth/                     Sign in with Apple (AuthService)
    ├── Reminders/                Local-notification scheduling
    ├── Onboarding/               Welcome screen
    └── Settings/                 Settings, theme, Pro toggles
```

---

## 3. Core Capabilities & Features

| Area | Feature |
|------|---------|
| **Projects** | Create categorized projects (self, child, plant, hair & beard, pet, other), each with a cadence (daily / every other day / weekly). |
| **Guided capture** | Live camera with rule-of-thirds + center guides; front/back camera with a smart default per category. Subject alignment is applied automatically at export by Smart Alignment (Pro) rather than a manual ghost. |
| **Streaks & activity** | Per-project day-streak, total frames, days running; a home “this week” bar chart and “capture due today” nudges. |
| **Reminders** | Opt-in local notifications at a chosen hour; scheduled per project cadence via `UNUserNotificationCenter`. |
| **Timelapse export** | One-tap MP4 render with a spinning-lens loading animation over a blurred page. **Speed:** 0.25×–3×. **Transitions:** Cut / Dissolve / Fade. **Alignment:** Off / Smart (Vision) / Manual (tap-to-mark the subject + zoom). **Overlays:** per-frame date stamp and a free-text note, each in a corner (never overlapping); app mark fixed bottom-right (Pro can hide it). Share via the system share sheet. |
| **Retake & manage** | View any frame full-screen, retake it in place, delete with confirmation. |
| **Themes** | Multiple selectable color themes, light/dark aware. |
| **Privacy-first** | Photos stay on device by default; iCloud sync is strictly opt-in. |
| **Localization** | Turkish (base) and English via String Catalogs (`.xcstrings`). |

---

## 4. Monetization & Business Logic

### Model: Freemium with a hard, honest free tier
Free users get a genuinely useful app; Pro removes limits and unlocks premium capabilities.

**Free tier limits (enforced in `FeatureGate`):**
- **1 active project** (`freeProjectLimit = 1`).
- **Up to 14 photos** in that project (`freeEntryLimit = 14`); the 15th prompts the paywall.
- Exports are **720×960 with a “TIMELAPSE” watermark**.

**Timelapse Pro unlocks:**
- Unlimited projects & unlimited photos per project.
- 4K (2160×2880) export with **no watermark** (app mark becomes optional & positionable).
- iCloud backup (opt-in).
- Smart Alignment — real, automatic subject alignment at export. `FrameAligner` uses **Vision**: `VNDetectFaceRectanglesRequest` (with roll) to lock a face to a consistent position, size **and angle** (it rotates frames to level the subject); when there's no face it falls back to attention-based **saliency** (`VNGenerateAttentionBasedSaliencyImageRequest`) so pets, plants and objects align too. Frames with no subject fall back to aspect-fill.
- **Couple Mode** — a project category ("Çift Modu"): two people are photographed in the same frame with an on-screen split guide.
- **Capture Together** — invite friends to collaborate on any project via the share sheet (marks the project collaborative). Live two-device sync additionally needs iCloud sharing / a paid account.

### Products & pricing
| Product ID | Type | Price |
|------------|------|-------|
| `com.ridvan.timelapse.pro.monthly` | Auto-renewable subscription (P1M) | **$0.50 / month** |
| `com.ridvan.timelapse.pro.lifetime` | Non-consumable (one-time) | **$3.99** |

> Prices are defined in `Products.storekit` for local testing and must be mirrored in App Store Connect for production. The paywall loads live localized prices from StoreKit and falls back to the configured amounts if products can’t load.

### Technical structure
- **`StoreService`** (StoreKit 2): loads products, purchases, restores, and — crucially — **derives entitlement live from `Transaction.currentEntitlements`** on every launch and via a long-lived `Transaction.updates` listener (handles renewals, refunds, Ask-to-Buy, cross-device). Entitlement is never persisted as a mutable flag.
- **`isPro` is the single source of truth**, read everywhere via `@Environment(StoreService.self)`.
- **`PaywallView` / `PaywallViewModel`**: subscription + lifetime options, a **Restore Purchases** button, the required auto-renewal disclosure, and **Terms of Use + Privacy Policy links** (Guideline 3.1.2).
- **Gating points:** project creation (`ProjectListView`), 15th photo (`ProjectDetailView`), export resolution/watermark (`TimelapseExportSettings.current(isPro:)`), and the Pro feature toggles in Settings.

### App Store compliance measures implemented
- **No IAP bypass ships to users.** A developer “unlock Pro without paying” test toggle and the admin unlock are compiled **`#if DEBUG` only** — the Release/App Store binary grants Pro *exclusively* through verified StoreKit purchases (Guidelines 2.3.1 & 3.1.1).
- **Subscription paywall** shows price, period, auto-renew terms, Restore, and Terms/Privacy links (3.1.2).
- **Privacy manifest** (`PrivacyInfo.xcprivacy`): declares no tracking and the required reason for UserDefaults access (`CA92.1`).
- **No ATT prompt / no IDFA** — the app contains no tracking, ads, or analytics SDKs, so App Tracking Transparency is intentionally *not* used (adding it would be incorrect).
- **Permissions** are purpose-stringed and requested lazily, only when the feature is used.

---

## 5. Technical Requirements & Setup

### Requirements
- **Xcode 16+**, **iOS 17.0+** deployment target.
- Swift 5 language mode. No package manager or third-party dependencies.
- A Mac with the full **Xcode.app** (not just Command Line Tools) to build/run.

### Permissions (Info.plist usage strings)
| Key | Why |
|-----|-----|
| `NSCameraUsageDescription` | Taking progress photos. |
| `ITSAppUsesNonExemptEncryption = NO` | No custom encryption; speeds up submission. |
| Notifications | Requested at runtime via `UNUserNotificationCenter` (no plist key required). |

### Capabilities
- **Sign in with Apple** and **iCloud / CloudKit** are wired in `Timelapse.entitlements` but **currently disabled** (the entitlements file is not referenced by `CODE_SIGN_ENTITLEMENTS`). These capabilities **require a paid Apple Developer Program membership** — a personal/free team cannot provision them. See “Enabling Apple ID & iCloud” below.

### Build & run
```bash
# 1. Open in Xcode
open Timelapse.xcodeproj

# 2. Select the "Timelapse" scheme + an iOS 17+ simulator or device
# 3. Build & run (⌘R)
```
The shared **Timelapse** scheme references `Products.storekit`, so **StoreKit prices work in the Simulator** with no App Store Connect setup.

Command-line build (uses full Xcode toolchain):
```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild build -scheme Timelapse \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Testing
74 unit tests cover monetization rules, the store override logic, export settings/speed, the composer, cadence, repository, and view models.
```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild test -scheme Timelapse \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```
> Note: two `CameraCaptureViewModelTests` cases can crash under simulator *diagnostic collection* when `xcode-select` points at Command Line Tools instead of Xcode.app; they pass in a normal Xcode test run. Point `xcode-select` at Xcode (`sudo xcode-select -s /Applications/Xcode.app`) for a clean CI run.

### Developer backdoor (DEBUG builds only)
To test Pro features without purchasing, in a **Debug** build: Settings → tap the **version number 7×** → “Geliştirici” section → enable **“Pro'yu Test Et.”** This code path does not exist in Release builds.

### Enabling Apple ID sign-in & iCloud (requires paid account)
1. Join the Apple Developer Program.
2. In Xcode → target **Timelapse → Signing & Capabilities**, add **Sign in with Apple** and **iCloud → CloudKit** (this sets `CODE_SIGN_ENTITLEMENTS` back to `Timelapse/Timelapse.entitlements`).
3. Rebuild. Admin unlock (email-hash allowlist in `AuthService`) and the iCloud backup toggle then function.

### Pre-submission checklist
- [ ] Replace `LegalLinks.privacyPolicy` / `.support` with your **hosted** URLs and enter the Privacy Policy URL in App Store Connect.
- [ ] Create the two IAP products in App Store Connect with matching IDs & prices; submit them with the build.
- [ ] Fill the **App Privacy** questionnaire (Data Not Collected if you keep photos local/iCloud-only and add no analytics).
- [ ] Provide review notes explaining the freemium limits and how to trigger the paywall.
- [ ] Confirm screenshots, app icon, and age rating.

---

## License / ownership
Proprietary — © 2026 Rıdvan Özcan. All rights reserved.
