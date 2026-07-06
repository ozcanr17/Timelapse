---
name: tasteskill
description: Rıdvan's strict UI/UX design taste for the Timelapse iOS app. Load BEFORE writing or changing ANY SwiftUI view, view modifier, color, font, spacing, animation, or component. Enforces a calm, professional, native Apple HIG aesthetic and bans futuristic/neon/gaming styling.
---

# tasteskill — Timelapse design law

Every piece of UI work in this app must pass these rules. When a request and a rule
conflict, the rule wins; surface the conflict instead of silently violating it.

## 1. The aesthetic (non-negotiable)
- **Calm, focused, highly professional native Apple HIG.** It should feel like a
  first-party Apple app (Photos, Fitness, Health, Journal), not a branded skin.
- **Premium & high-resolution.** Neutral tones, generous and consistent spacing,
  crisp typography, restrained use of color. Color earns its place; it is an accent,
  never decoration.
- **Content first.** The user's photos are the hero. Chrome recedes.

## 2. Hard bans (never ship these)
- ❌ Futuristic / sci-fi / "cyber" looks.
- ❌ Neon colors, glow effects, luminous halos, colored drop shadows.
- ❌ Gaming-style UI: aggressive gradients, laser edges, RGB, heavy bevels, arcade fonts.
- ❌ Faux "liquid glass" gimmicks used as decoration, oversaturated fills, busy backgrounds.
- ❌ Monospaced or novelty display fonts for primary UI text (timestamps/EXIF-style
  stamps on photos are the only allowed monospace use).

## 3. Positive rules (do these)
- **Typography:** SF Pro via `.system`. Prefer `design: .default`; `.rounded` only when
  a soft, friendly tone is explicitly wanted. Use Dynamic Type text styles
  (`.largeTitle`, `.title2`, `.headline`, `.body`, `.footnote`, `.caption`) so text scales.
- **Color:** neutral canvas/surface/ink from the theme. One accent per screen, used
  sparingly for the primary action and key highlights. Respect light & dark.
- **Depth:** use soft, neutral, *low-opacity black* shadows (e.g. `.black.opacity(0.04–0.08)`)
  or hairline separators — never colored/glowing shadows. Prefer `.ultraThinMaterial`
  and system materials over hand-rolled glass.
- **Spacing & shape:** consistent spacing scale (multiples of 4/8). Continuous rounded
  corners. Comfortable padding; let content breathe. Align to a grid.
- **Motion:** subtle, physical, purposeful. Gentle springs / `.smooth` easing. No flashy
  or attention-grabbing animation. Respect Reduce Motion.
- **Controls:** use native SwiftUI components and standard HIG controls, sizing, and
  tap targets (≥44pt). Standard navigation patterns.
- **Accessibility:** legible contrast (WCAG AA), Dynamic Type, VoiceOver labels, and
  Reduce Motion / Reduce Transparency honored.

## 4. Preserve functionality (CRITICAL)
- **Only touch the presentation layer** — SwiftUI views and view modifiers.
- Do **not** alter or remove business logic, data models, view-model APIs, service
  protocols, persistence, monetization/`FeatureGate` rules, or navigation behavior.
- Bind the new UI to the **existing** view-model properties and actions. Same inputs,
  same outputs — new skin only. If a redesign seems to need a logic change, stop and ask.

## 5. Repo house rules (always apply)
- **No comments in code.**
- **English-only identifiers.** User-facing strings stay localized (TR base + EN) via `.xcstrings`.
- Minimal token usage; work step-by-step and wait for "continue" before large moves.

## Quick self-check before finishing UI work
1. Would this look at home in a stock Apple app? If not, fix it.
2. Any neon / glow / colored shadow / cyber / gaming cue? Remove it.
3. Did I change only views/modifiers and keep all logic intact?
4. Light + dark both correct? Dynamic Type + VoiceOver OK?
