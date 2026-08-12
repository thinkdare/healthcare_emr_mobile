# Mobile App Visual Redesign — Design System + Flagship Flow

**Date:** 2026-08-12
**Status:** Approved (visual direction validated interactively via the brainstorming visual companion)

## Context

The app has 30+ screens across two platform-adaptive shells — `AndroidShell` (Material 3, drawer navigation, also used on web since `kIsIOS` is always false there) and `IOSShell` (Cupertino, bottom tab navigation). The current visual language is a generic, unstyled Material 3 blue (`#2563EB` seed color) with no distinctive identity, defined in `lib/config/theme.dart` and `lib/config/app_colors.dart`.

The user asked for a redesign covering web, iOS, and Android, referencing five stock UI-kit mood boards (a teal fintech app, a blue VPN/account-settings kit, a teal doctor-booking app, and a navy PayPal-style onboarding kit). None are EMR-specific — they served as style/mood references, not literal screens to copy. The user chose to synthesize a new direction rather than anchor on any single reference.

Redesigning all 30+ screens in one cycle is too large a unit of work. This spec covers:
1. A full design system (tokens + reusable component library, light and dark)
2. Applying that system to the flagship flow: **Login → Facility Picker → Provider Dashboard → Patient List → Patient Detail**

All other screens (Access Grants, Emergency Access, Subscription/Billing, Reporting, Staff Profile, Facilities, Referrals, Sync, Roster, More) automatically inherit the new base theme (colors, typography, default widget styling) but their bespoke layouts are **not** redesigned in this cycle. That is explicitly deferred to a follow-up spec once this system has shipped and been used in anger on the flagship flow.

The marketing/public web site in the sibling `healthcare-emr` Laravel repo is a separate, independently-scoped redesign (not covered here).

## Visual direction (validated via mockups)

Three palette directions and two typefaces were compared side-by-side as rendered mockups (dashboard stat cards, patient list rows with allergy badges, buttons) before landing here — see the approved screens for Dashboard (light + dark), Login, and Patient Detail Overview in `.superpowers/brainstorm/` (local scratch, gitignored — not the source of truth once this doc exists).

### Palette

**Light**
| Token | Value | Use |
|---|---|---|
| `background` | `#FBF9F5` | Screen background (warm cream, not stark white) |
| `surface` | `#FFFFFF` | Cards, sheets |
| `surfaceBorder` | `#F0EBE0` | Card/row borders |
| `surfaceTint` | `#EFEAE0` | Neutral stat tiles, secondary chips |
| `textPrimary` | `#292420` | Headlines, primary content |
| `textSecondary` | `#8A8071` | Meta text, labels |
| `textSecondaryAlt` | `#6B6355` | Secondary text on tinted surfaces |
| `accent` | `#1D4ED8` | Primary actions, links, active states, brand |
| `accentTint` | `#DBE7FE` | Accent chip/tile backgrounds |
| `critical` | `#B0392C` | Critical allergy, destructive actions, emergency |
| `criticalTint` | `#FBE4E1` | Critical banner/badge backgrounds |
| `criticalTintStrong` | border `#E8998C` | Critical card borders |

**Dark**
| Token | Value |
|---|---|
| `background` | `#201C18` (warm charcoal, not pure black) |
| `surface` | `#2C2420` |
| `surfaceBorder` | `#3A2F28` |
| `surfaceTint` | `#3A2F28` |
| `textPrimary` | `#F5EFE6` |
| `textSecondary` | `#A99C8C` |
| `accent` | `#5B87FA` |
| `accentTint` | `#22335F` |
| `critical` | `#F5A398` (text) on `#4A2420` (tint) |

Existing semantic `success`/`warning` hues carry over, re-tuned per-mode for contrast against the new backgrounds (exact values chosen during implementation, validated for WCAG AA contrast against both `surface` and `background`).

### Typography

**Plus Jakarta Sans**, weights 400/500/600/700/800. Chosen over Inter (too neutral/generic) and IBM Plex Sans (too technical/cold) for its warmth without sacrificing legibility at small sizes. Numeric figures (stat tiles, amounts) use tabular figures where the font/rendering path supports it.

Bundled as local font assets (`.ttf` files under e.g. `assets/fonts/`, declared in `pubspec.yaml`'s `fonts:` block, OFL license file included alongside) — **not** via the `google_fonts` package. That package's default behavior is to fetch font files over the network from Google's CDN on first use and cache them locally, which is incompatible with this app's offline-first posture (it already ships SQLite caching and offline banners on Patient List) and adds an undocumented third-party network call that a HIPAA data-flow review would flag. Bundling avoids both problems and any runtime dependency on connectivity for basic UI rendering.

### Spacing & shape

- Card radius: 16px. Control radius (buttons, inputs, tiles): 12px. Pills/badges: fully rounded (999px).
- Spacing scale: 4 / 8 / 12 / 16 / 24px, formalized as named constants rather than the current scattered literals.

### Key interaction pattern: critical-safety hierarchy

Patient Detail's Overview tab renders a **Critical Allergy card** (high-contrast, `critical`/`criticalTint` colors, warning icon) as the first card in the scroll, above medications, conditions, and everything else. This is a hard rule carried into the component library (`CriticalAlertCard`), not a one-off style choice — any screen surfacing life-threatening information must use this pattern and must render it first.

## Theming mechanism

- `ThemeMode` enum (system / light / dark), **defaulting to system**, with an explicit override control added to Staff Profile → Settings (a new settings section within the existing Profile tab structure).
- Preference persisted via `shared_preferences` (already a dependency).
- **Android/web (`AndroidShell`)**: `MaterialApp.themeMode` wired to the stored preference; add `AppTheme.darkTheme` alongside the existing `AppTheme.lightTheme`.
- **iOS (`IOSShell`)**: `CupertinoApp` has no built-in `themeMode`. Add a thin wrapper (e.g. `_ThemedCupertinoApp`) that reads the stored preference (falling back to `MediaQuery.platformBrightnessOf(context)` when set to "system"), and constructs `CupertinoThemeData(brightness: resolvedBrightness, primaryColor: ...)` accordingly. The preference needs to live above `CupertinoApp` (a `ChangeNotifier`-backed provider, consistent with the rest of the app's state approach) so changing it in Settings rebuilds the whole tree live, matching Material's `themeMode` behavior.

> **Note for implementation:** `AndroidShell` (Material) is also what web uses today, as a side effect of `main.dart`'s `kIsIOS ? IOSShell : AndroidShell` check (`kIsIOS` is always `false` on web) — not an intentional "web gets the Material shell" decision. The `MaterialApp.themeMode` wiring goes into `AndroidShell` and will therefore theme web too, which is desired, but a future contributor "fixing" that platform check could silently change which shell (and theming mechanism) web gets. Leave a comment at the check calling this out.

## Component library

Extends the existing adaptive-widget pattern in `lib/core/platform.dart` (`AdaptiveFilledButton`, `AdaptiveTextButton`, `AdaptiveDropdown`, `showAdaptiveDialog`, `showAdaptiveActionSheet`, `showAdaptiveToast`) rather than replacing it. New/updated pieces:

- `AdaptiveCard` — standard card container (surface + border + radius token), replacing ad hoc `Container`/`Card` usage in screen code.
- `StatTile` — icon/label/number tile used in dashboard-style stat rows.
- `AdaptiveListRow` — avatar/leading + title + subtitle + optional trailing badge, generalizing the current `PatientCard` pattern for reuse (facility rows, list items elsewhere).
- `AdaptiveBadge` (a.k.a. chip/pill) — fixed semantic → color mapping: `critical`, `warning`, `success`, `accent`, `neutral`. Always icon+text, never color alone (accessibility).
- `CriticalAlertCard` — the high-contrast safety-first pattern described above.
- Restyled `AdaptiveFilledButton`/`AdaptiveTextButton`/`AdaptiveDropdown`/dialogs/toasts to use the new tokens instead of the current `AppColors` constants.

`AppColors` and `AppTheme` are replaced with light/dark token classes (e.g. `AppColors.of(context)` or a `ThemeExtension`, decided during planning — the mechanism must work identically under both `Theme.of(context)` on Android/web and `CupertinoTheme.of(context)` on iOS). The current `AppTheme.primaryColor`-style static forwards are removed; the ~38 files currently referencing `AppColors.*`/`AppTheme.*` directly are migrated to theme-aware lookups as part of implementation.

**Sequencing:** this migration is a mechanical, large-blast-radius refactor (38 files) with no visual intent of its own — it should land as its own PR *before* the component library and flagship-screen redesign, not bundled into the same PR(s). Verify completeness with `grep -rn "AppColors\.\|AppTheme\." lib/` returning zero hits, rather than relying on review-by-eyeballing.

## Screens in this cycle

Rebuilt on the new tokens/components, in both shells where each screen is reachable:

1. **Login** (`login_screen.dart`) — all three steps (email, password, 2FA)
2. **Facility Picker** (`facility_picker_screen.dart`)
3. **Provider Dashboard** (`provider_dashboard_screen.dart`) — all cards (welcome, subscription/trial, patient overview, recent patients, access grants, emergency access, staff profile, active facility)
4. **Patient List** (`patient_list_screen.dart`) — including search and offline/error banners
5. **Patient Detail** (`patient_detail_screen.dart`) — all five tabs (Overview, Appointments, Prescriptions, Lab Results, Documents), including their FAB-triggered bottom sheet forms

Out of scope for this cycle (inherit base theme only, layouts untouched): Access Grants, Emergency Access, Subscription (Details/Upgrade/Expired/Invoices), Reporting, Staff Profile (beyond the new Settings toggle), Facilities, Provider Invitation, Referrals, Sync, Roster, More, Registration/Onboarding stubs.

## Testing

No general visual-regression infrastructure — disproportionate for this scope. For most of the redesign (dashboard cards, badges, general layout), rely on:
- `flutter analyze` passing
- Existing widget tests updated wherever they assert against the removed `AppColors`/`AppTheme` static constants
- Manual comparison of implemented screens against the approved mockups (light + dark, both shells)

**Exception — the critical-safety hierarchy is enforced by tests, not just convention.** Because `CriticalAlertCard`/"must render first" is a declared hard invariant (see above), it needs a mechanism that survives an unrelated future PR touching spacing or token defaults:
- A widget test asserting `CriticalAlertCard` (when present) is the first card in Patient Detail's Overview tab scroll.
- Programmatic contrast-ratio checks (WCAG AA, ≥4.5:1 for text) for `critical`-on-`criticalTint` in both light and dark `ThemeData`/`CupertinoThemeData`. The same check is applied to the re-tuned `success`/`warning` tokens once their final dark-mode values are chosen — "validated for WCAG AA" means this test passes, not a subjective look.

This is ~2-3 targeted tests, not a golden-image pipeline.

## Out of scope

- All non-flagship screens (see above) — follow-up spec.
- The marketing/public web site redesign (sibling `healthcare-emr` repo) — separate spec.
- App icon / launcher icon / splash screen — not raised by the user, not addressed here.
- Any new navigation model — the Material drawer / Cupertino tab-bar split is preserved as-is (per earlier decision), only visual treatment changes.
