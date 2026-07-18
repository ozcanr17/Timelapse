# Flapse — App Store Release Checklist

## Code & build (done in repo)
- [x] Release configuration: whole-module optimization, `-O`, `VALIDATE_PRODUCT=YES`
- [x] Zero build warnings in Release
- [x] 1024px app icon has no alpha channel
- [x] Privacy manifests in app **and** widget extension (UserDefaults, reasons CA92.1 + 1C8F.1)
- [x] `ITSAppUsesNonExemptEncryption = NO` (skips export-compliance prompt)
- [x] All permission strings present and localized via xcstrings (camera, photo add, photo read, location)
- [x] No third-party dependencies, no networking, no analytics — "Data Not Collected" is accurate
- [x] Unit tests green (`FlapseTests`)
- [x] CI workflow (`.github/workflows/ci.yml`)

## Before archiving (owner)
- [ ] Enable GitHub Pages (main `/docs`) so privacy/support/QR links resolve:
      `gh api repos/ozcanr17/Flapse/pages -X POST -f "source[branch]=main" -f "source[path]=/docs"`
- [ ] Paid Apple Developer account active; team selected in Signing & Capabilities
- [ ] Decide Sign in with Apple + CloudKit: either enable capabilities on the App ID
      or strip the entitlements before archiving (unprovisioned entitlements fail App Store signing)
- [ ] Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` if resubmitting
- [ ] Archive with Release config on a real device destination; validate in Organizer

## App Store Connect (owner, manual)
- [ ] Create app record: bundle ID `rozcan.Flapse`, name **Flapse**, category Productivity
- [ ] Create IAPs matching `Products.storekit`: `com.ridvan.timelapse.pro.monthly` / `.yearly` / `.lifetime`
- [ ] Attach subscription group + localized IAP metadata; submit IAPs with the binary
- [ ] Privacy questionnaire: **Data Not Collected**
- [ ] Privacy Policy URL: https://ozcanr17.github.io/Flapse/privacy
- [ ] Support URL: https://ozcanr17.github.io/Flapse/support
- [ ] Screenshots: 6.9" and 6.5" iPhone sets (portrait); optional iPad 13" set
- [ ] App Review notes: mention paywall restore flow, that no account is required,
      and how to trigger a render for the Live Activity
- [ ] TestFlight internal build first; verify Live Activity, background-retry, QR on device

## Post-approval
- [ ] Replace `LegalLinks.appSite` QR target with the App Store link if desired
- [ ] Monitor crash reports in Xcode Organizer
