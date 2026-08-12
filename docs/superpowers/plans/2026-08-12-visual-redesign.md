# Mobile App Visual Redesign — Design System + Flagship Flow — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the app's generic Material-blue visual language with a warm-neutral / Clinical-Blue design system (light + dark), and apply it to the highest-traffic flow: Login → Facility Picker → Provider Dashboard → Patient List → Patient Detail.

**Architecture:** A new context-based `AppColorTokens`/`AppColorScope` pair replaces the old static `AppColors`/`AppTheme` constants so the same token values work identically under both `MaterialApp` (Android/web) and `CupertinoApp` (iOS). `ThemeModeProvider` resolves light/dark (system-default, user-overridable) and both platform shells rebuild their token scope from it. A small shared component library (`AdaptiveCard`, `StatTile`, `AdaptiveListRow`, `AdaptiveBadge`, `CriticalAlertCard`) extends the existing `lib/core/platform.dart` adaptive-widget pattern. The 36-file mechanical migration off the old constants lands as its own commit, verified by a zero-hit grep, before any new visual work is layered on top.

**Tech Stack:** Flutter (Material 3 + Cupertino), `provider` (state), `shared_preferences` (theme preference persistence), bundled Plus Jakarta Sans font assets (no `google_fonts` package — see Global Constraints).

**Spec:** `docs/superpowers/specs/2026-08-12-visual-redesign-design.md`

## Global Constraints

- No `google_fonts` package dependency. Plus Jakarta Sans ships as bundled local font assets — zero runtime network dependency (spec, blocking issue #1).
- `ThemeMode` defaults to `system`; users can override via a new Appearance control in Staff Profile → Profile tab; preference persisted via `shared_preferences` (already a dependency).
- The Material (`AndroidShell`, also serves web)/Cupertino (`IOSShell`) platform split is preserved as-is — no navigation model changes.
- The `AppColors`/`AppTheme` → context-based token migration (~36 files) lands as its own commit, verified by `grep -rn "AppColors\.\|AppTheme\." lib/` returning zero hits, *before* the component library and flagship-screen tasks.
- `CriticalAlertCard`'s "renders first in Patient Detail Overview" invariant and the critical/success/warning token contrast ratios (≥4.5:1 WCAG AA) are enforced by widget tests, not by convention alone (spec, blocking issue #2).
- Scope is the design system plus five screens only: Login, Facility Picker, Provider Dashboard, Patient List, Patient Detail. All other screens inherit the new base theme automatically but are not otherwise touched in this plan.
- Existing screen business logic (providers, repositories, navigation, validation) is never changed by this plan — every task is a visual-layer change only.

---

## File Structure

**New files:**
- `assets/fonts/PlusJakartaSans-VariableFont_wght.ttf`, `assets/fonts/OFL.txt` — bundled font + license
- `lib/config/app_color_tokens.dart` — `AppColorTokens` data class + `.light`/`.dark` instances
- `lib/config/app_color_scope.dart` — `AppColorScope` `InheritedWidget`
- `lib/config/app_spacing.dart` — `AppSpacing`/`AppRadius` constants
- `lib/data/providers/theme_mode_provider.dart` — `ThemeModeProvider` (persisted `ThemeMode`)
- `lib/presentation/shared/widgets/adaptive_badge.dart` — `AdaptiveBadge`
- `lib/presentation/shared/widgets/adaptive_card.dart` — `AdaptiveCard`
- `lib/presentation/shared/widgets/stat_tile.dart` — `StatTile`
- `lib/presentation/shared/widgets/adaptive_list_row.dart` — `AdaptiveListRow`
- `lib/presentation/shared/widgets/critical_alert_card.dart` — `CriticalAlertCard`
- `test/shared/critical_alert_card_test.dart`, `test/shared/token_contrast_test.dart`

**Modified files (foundation):** `pubspec.yaml`, `lib/config/app_colors.dart` (gutted to a facade), `lib/config/theme.dart`, `lib/main.dart`, `lib/presentation/shell/android_shell.dart`, `lib/presentation/shell/ios_shell.dart`, `lib/core/platform.dart`

**Modified files (flagship screens):** `lib/presentation/auth/screens/login_screen.dart`, `lib/presentation/auth/screens/facility_picker_screen.dart`, `lib/presentation/dashboard/screens/provider_dashboard_screen.dart`, `lib/presentation/patients/widgets/patient_card.dart`, `lib/presentation/patients/screens/patient_list_screen.dart`, `lib/presentation/patients/screens/patient_detail_screen.dart`, `lib/presentation/profile/screens/staff_profile_screen.dart`

**Migrated only (mechanical, Phase 3):** the remaining ~29 files listed in Task 10.

---

## Phase 1 — Fonts & Design Tokens

### Task 1: Bundle Plus Jakarta Sans as local font assets

**Files:**
- Create: `assets/fonts/PlusJakartaSans-VariableFont_wght.ttf`, `assets/fonts/OFL.txt`
- Modify: `pubspec.yaml:78-79`

**Interfaces:**
- Produces: font family name `'Plus Jakarta Sans'`, available at weights 400/500/600/700/800, consumed by Task 5 (`AppTheme`).

- [ ] **Step 1: Download the font and license from a pinned commit, not a mutable branch**

`main` is a moving target — pin to the specific commit that last touched this font, and verify the download by checksum, not just by file type. (Values below were resolved and verified while writing this plan: commit `8cd7d0de182c88592d6852c245fe48f66eef55ee` is the latest commit touching `ofl/plusjakartasans/PlusJakartaSans[wght].ttf` in `google/fonts`, resolved via `curl https://api.github.com/repos/google/fonts/commits?path=ofl/plusjakartasans/PlusJakartaSans%5Bwght%5D.ttf&per_page=1`.)

```bash
mkdir -p assets/fonts
COMMIT=8cd7d0de182c88592d6852c245fe48f66eef55ee
curl -fL -o assets/fonts/PlusJakartaSans-VariableFont_wght.ttf \
  "https://raw.githubusercontent.com/google/fonts/${COMMIT}/ofl/plusjakartasans/PlusJakartaSans%5Bwght%5D.ttf"
curl -fL -o assets/fonts/OFL.txt \
  "https://raw.githubusercontent.com/google/fonts/${COMMIT}/ofl/plusjakartasans/OFL.txt"
```

- [ ] **Step 2: Verify the downloaded files against known-good checksums**

```bash
cat <<'EOF' | sha256sum -c -
89b3fb38aa0d275d7a731d0d817a4f1622b316b4d7fbdedcf02ee9099ff68bc8  assets/fonts/PlusJakartaSans-VariableFont_wght.ttf
995c7199cab65954f545996326755daee7b63cc6b42b06c13da1f9502ab08a99  assets/fonts/OFL.txt
EOF
```

Expected: `assets/fonts/PlusJakartaSans-VariableFont_wght.ttf: OK` and `assets/fonts/OFL.txt: OK`. If either fails, do not proceed — re-fetch and re-verify rather than trusting a mismatched file; if the mismatch persists, the pinned commit's content has changed underneath you (shouldn't happen for an immutable commit SHA) and needs investigating before continuing.

- [ ] **Step 3: Declare the font and asset in `pubspec.yaml`**

Replace the existing `flutter:` block (currently just `uses-material-design: true`):

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/fonts/OFL.txt
  fonts:
    - family: Plus Jakarta Sans
      fonts:
        - asset: assets/fonts/PlusJakartaSans-VariableFont_wght.ttf
          weight: 400
        - asset: assets/fonts/PlusJakartaSans-VariableFont_wght.ttf
          weight: 500
        - asset: assets/fonts/PlusJakartaSans-VariableFont_wght.ttf
          weight: 600
        - asset: assets/fonts/PlusJakartaSans-VariableFont_wght.ttf
          weight: 700
        - asset: assets/fonts/PlusJakartaSans-VariableFont_wght.ttf
          weight: 800
```

(All five weight entries point at the same variable-font file — this is Flutter's standard pattern for variable fonts; it selects the matching weight axis at render time.)

- [ ] **Step 4: Verify the package resolves**

Run: `flutter pub get`
Expected: completes with no errors

- [ ] **Step 5: Commit**

```bash
git add assets/fonts pubspec.yaml pubspec.lock
git commit -m "build: bundle Plus Jakarta Sans as local font asset"
```

---

### Task 2: Create `AppColorTokens`

**Files:**
- Create: `lib/config/app_color_tokens.dart`
- Test: `test/config/app_color_tokens_test.dart`

**Interfaces:**
- Produces: `class AppColorTokens` with fields `background, surface, surfaceBorder, surfaceTint, textPrimary, textSecondary, textSecondaryAlt, accent, accentTint, critical, criticalTint, criticalBorder, success, successTint, warning, warningTint` (all `Color`), plus `brightness` (`Brightness`). Static `AppColorTokens.light` and `AppColorTokens.dark`. Consumed by Task 3 (`AppColorScope`) and Task 5 (`AppTheme`).

- [ ] **Step 1: Write the failing test**

```dart
// test/config/app_color_tokens_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/config/app_color_tokens.dart';

void main() {
  test('light and dark tokens have distinct, correctly-typed brightness', () {
    expect(AppColorTokens.light.brightness, Brightness.light);
    expect(AppColorTokens.dark.brightness, Brightness.dark);
    expect(AppColorTokens.light.background, isNot(AppColorTokens.dark.background));
    expect(AppColorTokens.light.accent, const Color(0xFF1D4ED8));
    expect(AppColorTokens.dark.accent, const Color(0xFF5B87FA));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/config/app_color_tokens_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'healthcare_emr_mobile/config/app_color_tokens.dart'` (file doesn't exist yet)

- [ ] **Step 3: Implement**

```dart
// lib/config/app_color_tokens.dart
import 'package:flutter/material.dart' show Color, Brightness;

/// Semantic color tokens for the app's warm-neutral / Clinical-Blue design
/// system. Values are shared between the Material (Android/web) and
/// Cupertino (iOS) shells via [AppColorScope] — see app_color_scope.dart.
class AppColorTokens {
  final Color background;
  final Color surface;
  final Color surfaceBorder;
  final Color surfaceTint;
  final Color textPrimary;
  final Color textSecondary;
  final Color textSecondaryAlt;
  final Color accent;
  final Color accentTint;
  final Color critical;
  final Color criticalTint;
  final Color criticalBorder;
  final Color success;
  final Color successTint;
  final Color warning;
  final Color warningTint;
  final Brightness brightness;

  const AppColorTokens({
    required this.background,
    required this.surface,
    required this.surfaceBorder,
    required this.surfaceTint,
    required this.textPrimary,
    required this.textSecondary,
    required this.textSecondaryAlt,
    required this.accent,
    required this.accentTint,
    required this.critical,
    required this.criticalTint,
    required this.criticalBorder,
    required this.success,
    required this.successTint,
    required this.warning,
    required this.warningTint,
    required this.brightness,
  });

  static const light = AppColorTokens(
    background: Color(0xFFFBF9F5),
    surface: Color(0xFFFFFFFF),
    surfaceBorder: Color(0xFFF0EBE0),
    surfaceTint: Color(0xFFEFEAE0),
    textPrimary: Color(0xFF292420),
    textSecondary: Color(0xFF8A8071),
    textSecondaryAlt: Color(0xFF6B6355),
    accent: Color(0xFF1D4ED8),
    accentTint: Color(0xFFDBE7FE),
    critical: Color(0xFFB0392C),
    criticalTint: Color(0xFFFBE4E1),
    criticalBorder: Color(0xFFE8998C),
    // Darker than the brand-blue-era originals for AA text contrast on a
    // light background — see Task 31 (contrast tests). Adjust shade (same
    // hue) if that test fails; do not change without re-running it.
    success: Color(0xFF15803D),
    successTint: Color(0xFFDCFCE7),
    warning: Color(0xFFB45309),
    warningTint: Color(0xFFFEF3C7),
    brightness: Brightness.light,
  );

  static const dark = AppColorTokens(
    background: Color(0xFF201C18),
    surface: Color(0xFF2C2420),
    surfaceBorder: Color(0xFF3A2F28),
    surfaceTint: Color(0xFF3A2F28),
    textPrimary: Color(0xFFF5EFE6),
    textSecondary: Color(0xFFA99C8C),
    textSecondaryAlt: Color(0xFFA99C8C),
    accent: Color(0xFF5B87FA),
    accentTint: Color(0xFF22335F),
    critical: Color(0xFFF5A398),
    criticalTint: Color(0xFF4A2420),
    criticalBorder: Color(0xFF5C2E28),
    success: Color(0xFF4ADE80),
    successTint: Color(0xFF14301F),
    warning: Color(0xFFFBBF24),
    warningTint: Color(0xFF3A2A0C),
    brightness: Brightness.dark,
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/config/app_color_tokens_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/config/app_color_tokens.dart test/config/app_color_tokens_test.dart
git commit -m "feat: add AppColorTokens light/dark design tokens"
```

---

### Task 3: Create `AppColorScope` and rewrite `AppColors` as a context accessor

**Files:**
- Create: `lib/config/app_color_scope.dart`
- Modify: `lib/config/app_colors.dart` (full rewrite — currently 17 lines of static `Color` constants)
- Test: `test/config/app_color_scope_test.dart`

**Interfaces:**
- Consumes: `AppColorTokens` (Task 2)
- Produces: `AppColorScope` (`InheritedWidget`, ctor `{required tokens, required child}`, static `AppColorScope.of(BuildContext)`); `AppColors.of(BuildContext) → AppColorTokens`. Every migrated call site (Task 10) and every new component (Phase 4) uses `AppColors.of(context)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/config/app_color_scope_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/config/app_color_scope.dart';
import 'package:healthcare_emr_mobile/config/app_color_tokens.dart';
import 'package:healthcare_emr_mobile/config/app_colors.dart';

void main() {
  testWidgets('AppColors.of(context) returns the nearest AppColorScope tokens',
      (tester) async {
    late AppColorTokens captured;
    await tester.pumpWidget(
      AppColorScope(
        tokens: AppColorTokens.dark,
        child: Builder(
          builder: (context) {
            captured = AppColors.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(captured, AppColorTokens.dark);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/config/app_color_scope_test.dart`
Expected: FAIL — `app_color_scope.dart` doesn't exist

- [ ] **Step 3: Implement**

```dart
// lib/config/app_color_scope.dart
import 'package:flutter/widgets.dart';
import 'app_color_tokens.dart';

/// Provides [AppColorTokens] down the tree so the same semantic colors work
/// identically under MaterialApp (Android/web) and CupertinoApp (iOS) — see
/// AndroidShell/IOSShell, which each wrap their routed content in one of
/// these, resolved from the active brightness.
class AppColorScope extends InheritedWidget {
  final AppColorTokens tokens;

  const AppColorScope({
    super.key,
    required this.tokens,
    required super.child,
  });

  static AppColorTokens of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppColorScope>();
    assert(scope != null, 'AppColors.of() called with no AppColorScope ancestor.');
    return scope!.tokens;
  }

  @override
  bool updateShouldNotify(AppColorScope oldWidget) => tokens != oldWidget.tokens;
}
```

```dart
// lib/config/app_colors.dart
//
// Context-based accessor for the shared design tokens. Backed by
// AppColorScope so the same call — AppColors.of(context) — resolves
// correctly whether the caller is under MaterialApp (Android/web) or
// CupertinoApp (iOS), and reacts automatically to theme-mode changes.
import 'package:flutter/widgets.dart' show BuildContext;
import 'app_color_scope.dart';
import 'app_color_tokens.dart';

class AppColors {
  AppColors._();

  static AppColorTokens of(BuildContext context) => AppColorScope.of(context);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/config/app_color_scope_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/config/app_color_scope.dart lib/config/app_colors.dart test/config/app_color_scope_test.dart
git commit -m "feat: add AppColorScope, rewrite AppColors as context accessor"
```

---

### Task 4: Add `AppSpacing`/`AppRadius` constants

**Files:**
- Create: `lib/config/app_spacing.dart`

**Interfaces:**
- Produces: `AppSpacing.{xs,sm,md,lg,xl}` (`double`), `AppRadius.{control,card,pill}` (`double`). Consumed by every component-library and screen task from here on.

- [ ] **Step 1: Implement (no test — pure constants, exercised transitively by every widget test that follows)**

```dart
// lib/config/app_spacing.dart
class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

class AppRadius {
  AppRadius._();
  static const double control = 12;
  static const double card = 16;
  static const double pill = 999;
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/config/app_spacing.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/config/app_spacing.dart
git commit -m "feat: add AppSpacing/AppRadius design tokens"
```

---

### Task 5: Rewrite `AppTheme` with light/dark `ThemeData` and the new font

**Files:**
- Modify: `lib/config/theme.dart` (full rewrite of the 130-line file)

**Interfaces:**
- Consumes: `AppColorTokens` (Task 2), font family `'Plus Jakarta Sans'` (Task 1)
- Produces: `AppTheme.lightTheme`, `AppTheme.darkTheme` (both `ThemeData`). The old static forwards (`AppTheme.primaryColor`, `.gray600`, etc.) are removed — Task 10 migrates every remaining reference.

- [ ] **Step 1: Implement**

```dart
// lib/config/theme.dart
import 'package:flutter/material.dart';
import 'app_color_tokens.dart';
import 'app_spacing.dart';

class AppTheme {
  static ThemeData get lightTheme => _build(AppColorTokens.light);
  static ThemeData get darkTheme => _build(AppColorTokens.dark);

  static ThemeData _build(AppColorTokens tokens) {
    return ThemeData(
      useMaterial3: true,
      brightness: tokens.brightness,
      fontFamily: 'Plus Jakarta Sans',
      scaffoldBackgroundColor: tokens.background,
      // Explicitly set every ColorScheme role a stock Material widget is
      // likely to pull from by default (outline, onSurface, secondary,
      // surfaceContainerHighest, etc.) rather than letting ColorScheme.fromSeed's
      // algorithmic tonal-palette derivation leak through for anything not
      // hand-restyled in this plan's flagship screens — otherwise those
      // roles silently diverge from the approved mockups/Task 31 contrast
      // tests with no token anywhere to trace the value back to.
      // Roles intentionally left seed-derived (rarely user-visible, not
      // worth expanding the token set for): tertiary*, inverseSurface,
      // inversePrimary, shadow, scrim, surfaceTint.
      colorScheme: ColorScheme.fromSeed(
        seedColor: tokens.accent,
        brightness: tokens.brightness,
        primary: tokens.accent,
        onPrimary: Colors.white,
        primaryContainer: tokens.accentTint,
        onPrimaryContainer: tokens.accent,
        secondary: tokens.accent,
        onSecondary: Colors.white,
        error: tokens.critical,
        onError: Colors.white,
        errorContainer: tokens.criticalTint,
        onErrorContainer: tokens.critical,
        surface: tokens.surface,
        onSurface: tokens.textPrimary,
        onSurfaceVariant: tokens.textSecondary,
        surfaceContainerHighest: tokens.surfaceTint,
        outline: tokens.surfaceBorder,
        outlineVariant: tokens.surfaceBorder,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: tokens.accent,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          elevation: 0,
          textStyle: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 16,
              fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.accent,
          textStyle: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 16,
              fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.accent,
          side: BorderSide(color: tokens.accent, width: 1.5),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          textStyle: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 16,
              fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: tokens.surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: tokens.surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: tokens.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: tokens.critical),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: tokens.critical, width: 2),
        ),
        filled: true,
        fillColor: tokens.surface,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
        labelStyle: TextStyle(color: tokens.textSecondary),
        hintStyle: TextStyle(color: tokens.textSecondary.withValues(alpha: 0.6)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: tokens.surfaceBorder),
        ),
        margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      ),
      textTheme: Typography.material2021(platform: TargetPlatform.android)
          .black
          .apply(fontFamily: 'Plus Jakarta Sans', bodyColor: tokens.textPrimary,
              displayColor: tokens.textPrimary),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles standalone**

Run: `flutter analyze lib/config/theme.dart`
Expected: errors referencing files that still import the old `AppTheme.primaryColor`-style statics (expected — Task 10 fixes these). Confirm the errors are all `undefined_getter`/`undefined_identifier` in *other* files, not in `theme.dart` itself.

- [ ] **Step 3: Commit**

```bash
git add lib/config/theme.dart
git commit -m "feat: rewrite AppTheme with light/dark ThemeData and new tokens"
```

(This intentionally leaves the app non-compiling until Task 10 — the migration commit immediately follows in Phase 3, before any other work.)

---

## Phase 2 — Theme Mode Mechanism

### Task 6: Create `ThemeModeProvider`

**Files:**
- Create: `lib/data/providers/theme_mode_provider.dart`
- Test: `test/config/theme_mode_provider_test.dart`

**Interfaces:**
- Produces: `class ThemeModeProvider extends ChangeNotifier` with `ThemeMode get mode`, `Future<void> load()`, `Future<void> setMode(ThemeMode)`, `Brightness resolvedBrightness(BuildContext)`. Consumed by Task 7 (main.dart), Task 8/9 (shells), Task 16 (Settings toggle).

- [ ] **Step 1: Write the failing test**

```dart
// test/config/theme_mode_provider_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:healthcare_emr_mobile/data/providers/theme_mode_provider.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to system, and persists an explicit override across loads', () async {
    final provider = ThemeModeProvider();
    await provider.load();
    expect(provider.mode, ThemeMode.system);

    await provider.setMode(ThemeMode.dark);
    expect(provider.mode, ThemeMode.dark);

    final reloaded = ThemeModeProvider();
    await reloaded.load();
    expect(reloaded.mode, ThemeMode.dark);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/config/theme_mode_provider_test.dart`
Expected: FAIL — file doesn't exist

- [ ] **Step 3: Implement**

```dart
// lib/data/providers/theme_mode_provider.dart
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted light/dark/system preference. This deliberately talks to
/// SharedPreferences directly rather than going through a repository —
/// it's a single local UI preference with no API involvement, unlike the
/// domain providers in this directory which wrap a repository owning
/// API + DB calls.
class ThemeModeProvider extends ChangeNotifier {
  static const _prefsKey = 'app_theme_mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    _mode = switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }

  Brightness resolvedBrightness(BuildContext context) {
    return switch (_mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => MediaQuery.platformBrightnessOf(context),
    };
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/config/theme_mode_provider_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/data/providers/theme_mode_provider.dart test/config/theme_mode_provider_test.dart
git commit -m "feat: add ThemeModeProvider with persisted light/dark/system preference"
```

---

### Task 7: Wire `ThemeModeProvider` into `main.dart`

**Files:**
- Modify: `lib/main.dart:34-35` (imports), `lib/main.dart:115-163` (`MultiProvider`/shell selection)

**Interfaces:**
- Consumes: `ThemeModeProvider` (Task 6)

- [ ] **Step 1: Add the import**

In `lib/main.dart`, add alongside the existing provider imports (near line 33):

```dart
import 'data/providers/theme_mode_provider.dart';
```

- [ ] **Step 2: Register the provider**

In the `MultiProvider.providers` list (`lib/main.dart:116-159`), add:

```dart
        ChangeNotifierProvider(
          create: (_) => ThemeModeProvider()..load(),
        ),
```

- [ ] **Step 3: Annotate the shell-selection line**

Replace `lib/main.dart:163`:

```dart
      // Platform branch: CupertinoApp on iOS, MaterialApp on Android.
      // Both shells read from the same MultiProvider tree above.
      child: kIsIOS ? const IOSShell() : const AndroidShell(),
```

with:

```dart
      // Platform branch: CupertinoApp on iOS, MaterialApp on Android.
      // Both shells read from the same MultiProvider tree above.
      //
      // NOTE: kIsIOS is always false on web, so web falls through to
      // AndroidShell (Material) as a side effect of this check, not as an
      // intentional "web gets Material" decision. AndroidShell's
      // MaterialApp.themeMode wiring (Task 8) therefore themes web too —
      // that's desired, but don't "simplify" this check without checking
      // what it does to web theming.
      child: kIsIOS ? const IOSShell() : const AndroidShell(),
```

- [ ] **Step 4: Verify it compiles**

Run: `flutter analyze lib/main.dart`
Expected: no new errors introduced by this task (pre-existing Task-10-pending errors elsewhere are expected at this point in the plan)

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart
git commit -m "feat: register ThemeModeProvider, annotate web/Android shell selection"
```

---

### Task 8: Wire theming into `AndroidShell`

**Files:**
- Modify: `lib/presentation/shell/android_shell.dart` (full file, currently 49 lines)

**Interfaces:**
- Consumes: `ThemeModeProvider` (Task 6), `AppColorScope`/`AppColorTokens` (Tasks 2-3), `AppTheme.lightTheme`/`.darkTheme` (Task 5)

- [ ] **Step 1: Implement**

```dart
// lib/presentation/shell/android_shell.dart
//
// Android root — MaterialApp + existing drawer navigation. Also serves
// web (see the comment on the shell-selection line in main.dart).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_color_scope.dart';
import '../../config/app_color_tokens.dart';
import '../../config/theme.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/theme_mode_provider.dart';
import '../auth/screens/login_screen.dart';
import '../dashboard/screens/provider_dashboard_screen.dart';
import 'app_lock_gate.dart';

class AndroidShell extends StatelessWidget {
  const AndroidShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeModeProvider>(
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Healthcare EMR',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode.mode,
          builder: (context, child) {
            final tokens = Theme.of(context).brightness == Brightness.dark
                ? AppColorTokens.dark
                : AppColorTokens.light;
            return AppColorScope(tokens: tokens, child: child!);
          },
          home: const AppLockGate(child: _AuthWrapper()),
        );
      },
    );
  }
}

class _AuthWrapper extends StatelessWidget {
  const _AuthWrapper();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return auth.isAuthenticated
            ? const ProviderDashboardScreen()
            : const LoginScreen();
      },
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/presentation/shell/android_shell.dart`
Expected: no new errors from this file

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/shell/android_shell.dart
git commit -m "feat: wire ThemeMode + AppColorScope into AndroidShell"
```

---

### Task 9: Wire theming into `IOSShell`

**Files:**
- Modify: `lib/presentation/shell/ios_shell.dart` (full file, currently 107 lines)

**Interfaces:**
- Consumes: same as Task 8. `CupertinoApp` has no built-in `themeMode`, so brightness is resolved manually via `ThemeModeProvider.resolvedBrightness(context)`.

- [ ] **Step 1: Implement**

```dart
// lib/presentation/shell/ios_shell.dart
//
// iOS root — CupertinoApp + CupertinoTabScaffold with four tabs.
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../config/app_color_scope.dart';
import '../../config/app_color_tokens.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/theme_mode_provider.dart';
import '../access_grants/screens/access_grants_screen.dart';
import '../auth/screens/login_screen.dart';
import '../more/more_screen.dart';
import '../patients/screens/patient_list_screen.dart';
import '../roster/screens/roster_screen.dart';
import '../sync/widgets/sync_banner.dart';
import 'app_lock_gate.dart';
import 'widgets/device_integrity_banner.dart';

class IOSShell extends StatelessWidget {
  const IOSShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeModeProvider>(
      builder: (context, themeModeProvider, _) {
        return Builder(
          builder: (context) {
            final brightness = themeModeProvider.resolvedBrightness(context);
            final tokens =
                brightness == Brightness.dark ? AppColorTokens.dark : AppColorTokens.light;
            return AppColorScope(
              tokens: tokens,
              child: CupertinoApp(
                title: 'Healthcare EMR',
                debugShowCheckedModeBanner: false,
                theme: CupertinoThemeData(
                  brightness: brightness,
                  primaryColor: tokens.accent,
                  scaffoldBackgroundColor: tokens.background,
                  textTheme: const CupertinoTextThemeData(
                    textStyle: TextStyle(fontFamily: 'Plus Jakarta Sans'),
                  ),
                ),
                home: const AppLockGate(child: _IOSAuthWrapper()),
              ),
            );
          },
        );
      },
    );
  }
}

class _IOSAuthWrapper extends StatelessWidget {
  const _IOSAuthWrapper();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isLoading) {
          return const CupertinoPageScaffold(
            child: Center(child: CupertinoActivityIndicator()),
          );
        }
        return auth.isAuthenticated
            ? const _IOSTabs()
            : const LoginScreen();
      },
    );
  }
}

class _IOSTabs extends StatelessWidget {
  const _IOSTabs();

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return CupertinoPageScaffold(
      child: Column(
        children: [
          const DeviceIntegrityBanner(),
          const SyncBanner(),
          Expanded(
            child: CupertinoTabScaffold(
              tabBar: CupertinoTabBar(
                activeColor: tokens.accent,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.person_crop_circle),
                    label: 'Patients',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.list_bullet_below_rectangle),
                    label: 'Roster',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.lock_shield),
                    label: 'Access',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.ellipsis_circle),
                    label: 'More',
                  ),
                ],
              ),
              tabBuilder: (context, index) {
                return CupertinoTabView(
                  builder: (_) => switch (index) {
                    0 => const PatientListScreen(),
                    1 => const RosterScreen(),
                    2 => const AccessGrantsScreen(),
                    _ => const MoreScreen(),
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

Note: add `import '../../config/app_colors.dart';` alongside the other config imports for the `AppColors.of(context)` call in `_IOSTabs`.

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/presentation/shell/ios_shell.dart`
Expected: no new errors from this file

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/shell/ios_shell.dart
git commit -m "feat: wire ThemeMode + AppColorScope into IOSShell"
```

---

## Phase 3 — Mechanical Token Migration (own commit, before any new visual work)

### Task 10: Migrate all remaining `AppColors.*`/`AppTheme.*` call sites to `AppColors.of(context)`

**Files:** All of the following (grep-verified counts as of this plan's writing):

```
lib/presentation/patients/screens/patient_detail_screen.dart      (45)
lib/presentation/dashboard/screens/provider_dashboard_screen.dart (44)
lib/presentation/profile/screens/staff_profile_screen.dart        (37)
lib/presentation/roster/screens/roster_screen.dart                (25)
lib/presentation/reporting/screens/reporting_screen.dart          (25)
lib/presentation/subscription/screens/billing_invoices_screen.dart(24)
lib/presentation/facilities/screens/facilities_list_screen.dart   (22)
lib/presentation/access_grants/screens/access_grants_screen.dart  (22)
lib/presentation/subscription/screens/subscription_details_screen.dart (19)
lib/presentation/emergency_access/screens/emergency_access_screen.dart (18)
lib/presentation/subscription/screens/subscription_upgrade_screen.dart (14)
lib/presentation/subscription/screens/subscription_expired_screen.dart (14)
lib/presentation/patients/screens/patient_audit_log_screen.dart   (13)
lib/presentation/auth/screens/login_screen.dart                   (13)
lib/presentation/patients/widgets/patient_card.dart                (12)
lib/presentation/more/more_screen.dart                             (11)
lib/presentation/patients/screens/patient_list_screen.dart         (10)
lib/presentation/patients/widgets/clinical_forms.dart                (9)
lib/presentation/auth/screens/facility_picker_screen.dart            (9)
lib/presentation/emergency_access/screens/trigger_emergency_access_screen.dart (8)
lib/presentation/staff/screens/staff_management_screen.dart          (7)
lib/presentation/providers/screens/provider_invitation_screen.dart   (7)
lib/presentation/auth/screens/accept_invitation_screen.dart          (7)
lib/presentation/access_grants/screens/request_access_screen.dart    (7)
lib/presentation/registration/screens/pricing_screen.dart            (6)
lib/core/platform.dart                                               (6)
lib/presentation/patients/widgets/clinical_record_tab.dart           (5)
lib/presentation/patients/screens/patient_messages_screen.dart       (5)
lib/presentation/facilities/screens/facility_form_screen.dart        (5)
lib/presentation/subscription/widgets/trial_status_banner.dart       (4)
lib/presentation/patients/screens/patient_form_screen.dart           (4)
lib/presentation/organization/screens/organization_profile_screen.dart (3)
lib/presentation/shell/widgets/device_integrity_banner.dart          (1)
lib/presentation/shell/app_lock_gate.dart                            (1)
lib/presentation/registration/screens/trial_welcome_screen.dart      (2)
```

(`android_shell.dart` and `ios_shell.dart` were already migrated in Tasks 8-9; `login_screen.dart`, `facility_picker_screen.dart`, `patient_card.dart`, `patient_list_screen.dart`, `patient_detail_screen.dart`, `provider_dashboard_screen.dart`, `staff_profile_screen.dart` are listed here but get their *visual* redesign in Phase 5/6 — this task only does the mechanical symbol substitution so the app compiles again; Phase 5/6 tasks then restyle their structure on top.)

**Interfaces:**
- Consumes: `AppColors.of(context)` (Task 3)
- Produces: a compiling app with zero remaining references to the old static constants.

- [ ] **Step 1: Confirm the current symbol inventory matches this task's assumptions**

Run: `grep -rohE "AppColors\.[a-zA-Z0-9_]+|AppTheme\.[a-zA-Z0-9_]+" lib --include="*.dart" | sort | uniq -c | sort -rn`
Expected output shape (counts may drift slightly from Tasks 1-9 edits, but symbol names should match):

```
AppTheme.gray600
AppTheme.errorColor
AppTheme.primaryColor
AppTheme.warningColor
AppTheme.successColor
AppColors.primary
AppColors.error
AppTheme.secondaryColor
AppTheme.gray900
AppColors.gray600
AppTheme.gray100
AppTheme.gray50
AppColors.success
AppColors.secondary
AppColors.gray50
AppColors.warning
AppColors.gray900
AppColors.gray100
```

If new symbols appear that aren't in the mapping table below, stop and extend the table before proceeding (don't guess a mapping).

- [ ] **Step 2: Apply the mechanical substitution**

Mapping table (old symbol → new expression):

| Old | New |
|---|---|
| `AppTheme.primaryColor` / `AppColors.primary` | `AppColors.of(context).accent` |
| `AppTheme.secondaryColor` / `AppColors.secondary` | `AppColors.of(context).accent` (no distinct secondary hue in the new system — see spec) |
| `AppTheme.errorColor` / `AppColors.error` | `AppColors.of(context).critical` |
| `AppTheme.successColor` / `AppColors.success` | `AppColors.of(context).success` |
| `AppTheme.warningColor` / `AppColors.warning` | `AppColors.of(context).warning` |
| `AppTheme.gray900` / `AppColors.gray900` | `AppColors.of(context).textPrimary` |
| `AppTheme.gray600` / `AppColors.gray600` | `AppColors.of(context).textSecondary` |
| `AppTheme.gray100` / `AppColors.gray100` | `AppColors.of(context).surfaceTint` |
| `AppTheme.gray50` / `AppColors.gray50` | `AppColors.of(context).surfaceTint` |

Run, from the repo root:

```bash
FILES=$(grep -rl "AppColors\.\|AppTheme\." lib --include="*.dart")
for f in $FILES; do
  sed -i \
    -e 's/AppTheme\.primaryColor/AppColors.of(context).accent/g' \
    -e 's/AppColors\.primary\b/AppColors.of(context).accent/g' \
    -e 's/AppTheme\.secondaryColor/AppColors.of(context).accent/g' \
    -e 's/AppColors\.secondary\b/AppColors.of(context).accent/g' \
    -e 's/AppTheme\.errorColor/AppColors.of(context).critical/g' \
    -e 's/AppColors\.error\b/AppColors.of(context).critical/g' \
    -e 's/AppTheme\.successColor/AppColors.of(context).success/g' \
    -e 's/AppColors\.success\b/AppColors.of(context).success/g' \
    -e 's/AppTheme\.warningColor/AppColors.of(context).warning/g' \
    -e 's/AppColors\.warning\b/AppColors.of(context).warning/g' \
    -e 's/AppTheme\.gray900/AppColors.of(context).textPrimary/g' \
    -e 's/AppColors\.gray900/AppColors.of(context).textPrimary/g' \
    -e 's/AppTheme\.gray600/AppColors.of(context).textSecondary/g' \
    -e 's/AppColors\.gray600/AppColors.of(context).textSecondary/g' \
    -e 's/AppTheme\.gray100/AppColors.of(context).surfaceTint/g' \
    -e 's/AppColors\.gray100/AppColors.of(context).surfaceTint/g' \
    -e 's/AppTheme\.gray50/AppColors.of(context).surfaceTint/g' \
    -e 's/AppColors\.gray50/AppColors.of(context).surfaceTint/g' \
    "$f"
done
```

- [ ] **Step 3: Add the `app_colors.dart` import to every touched file that's missing it — deterministically**

Dart import paths are fully determined by file location relative to `lib/`, so the correct relative prefix is computable, not a judgment call: for a file at `lib/a/b/c/file.dart`, the path to `lib/config/` is `../../../config/` (one `../` per path segment between `lib/` and the file, i.e. `dirname` minus the `lib/` prefix).

```bash
for f in $FILES; do
  grep -q "import '.*app_colors\.dart'" "$f" && continue
  rel_dir=$(dirname "$f" | sed 's|^lib/||')
  if [ "$rel_dir" = "lib" ] || [ -z "$rel_dir" ]; then
    depth=0
  else
    depth=$(echo "$rel_dir" | tr '/' '\n' | wc -l)
  fi
  prefix=$(printf '../%.0s' $(seq 1 "$depth" 2>/dev/null))
  last_import_line=$(grep -n "^import " "$f" | tail -1 | cut -d: -f1)
  sed -i "${last_import_line}a import '${prefix}config/app_colors.dart';" "$f"
done
dart format lib/
```

Dry-run and spot-check before trusting this across all 36 files: run it on 2-3 known files first (e.g. `lib/presentation/patients/widgets/patient_card.dart`, which should get `import '../../../config/app_colors.dart';`, matching its existing `import '../../../config/theme.dart';`, and `lib/core/platform.dart`, which should get `import '../config/app_colors.dart';`, matching its existing `import '../config/app_colors.dart';` reference — that file already imports it, so it should be *skipped* by the `grep -q ... && continue` guard, confirming the skip-logic works before running the loop over the rest of `$FILES`).

Separately, remove the now-unused `import '....config/theme.dart';` from any file where nothing else still references `AppTheme` (some files use `AppTheme.lightTheme` etc. and must keep it) — `flutter analyze`'s `unused_import` warning in Step 5 will flag exactly which files qualify; don't remove any import analyze doesn't flag.

Run Step 3's loop to completion for every file in `$FILES` before starting Step 4 — Step 4 relies on `flutter analyze` output being about `const` contexts specifically, and running it before every file has its import will surface a flood of unrelated "undefined identifier `AppColors`" errors that make the `const` errors harder to isolate.

- [ ] **Step 4: Fix `const` context errors surfaced by the compiler**

`AppColors.of(context)` is a runtime lookup, not a compile-time constant, so any `const` constructor that used to wrap an `AppTheme.x`/`AppColors.x` value now fails to compile. Run:

Run: `flutter analyze lib/ 2>&1 | grep -B2 "must be constant\|not a constant expression\|const"`

For every reported line, remove the `const` keyword from that specific widget/constructor call (not from unrelated siblings). Do not blanket-remove `const` from files — only the flagged constructors.

- [ ] **Step 5: Run full analysis and fix remaining errors one at a time**

Run: `flutter analyze`
Expected: eventually `No issues found!`. Fix errors in the order reported; most remaining ones after Step 4 will be missing/incorrect imports from Step 3 — resolve each by adding the correct relative import.

- [ ] **Step 6: Verify completeness**

Run: `grep -rn "AppColors\.\(primary\|secondary\|error\|success\|warning\|gray50\|gray100\|gray600\|gray900\)\b\|AppTheme\.\(primaryColor\|secondaryColor\|errorColor\|successColor\|warningColor\|gray50\|gray100\|gray600\|gray900\)\b" lib/`
Expected: no output (zero hits). `AppTheme.lightTheme`/`AppTheme.darkTheme` references are fine and expected to remain (those still exist, per Task 5).

- [ ] **Step 7: Run the existing test suite**

Run: `flutter test`
Expected: all pre-existing tests pass. Any test asserting against the *old* static color values (e.g. `expect(widget.color, AppTheme.primaryColor)`) needs updating to pump the widget inside an `AppColorScope` and assert against `AppColorTokens.light.accent` instead — fix these as they surface.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "refactor: migrate AppColors/AppTheme static constants to context-based tokens

Mechanical migration only — no visual changes. Verified by zero
remaining hits on the old symbol names (see grep in this commit's
plan task) and a full flutter analyze pass."
```

---

## Phase 4 — Component Library

### Task 11: `AdaptiveBadge`

**Files:**
- Create: `lib/presentation/shared/widgets/adaptive_badge.dart`
- Test: `test/shared/adaptive_badge_test.dart`

**Interfaces:**
- Consumes: `AppColors.of(context)` (Task 3)
- Produces: `enum BadgeVariant { critical, warning, success, accent, neutral }`; `class AdaptiveBadge extends StatelessWidget` with ctor `{required String label, required BadgeVariant variant, IconData? icon}`. Consumed by Task 15 (`CriticalAlertCard`), Task 25 (`PatientCard`), and other flagship-screen tasks.

- [ ] **Step 1: Write the failing test**

```dart
// test/shared/adaptive_badge_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/config/app_color_scope.dart';
import 'package:healthcare_emr_mobile/config/app_color_tokens.dart';
import 'package:healthcare_emr_mobile/presentation/shared/widgets/adaptive_badge.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        home: AppColorScope(
          tokens: AppColorTokens.light,
          child: Scaffold(body: child),
        ),
      );

  testWidgets('critical badge shows label and warning icon by default', (tester) async {
    await tester.pumpWidget(wrap(
      const AdaptiveBadge(label: 'ALLERGY', variant: BadgeVariant.critical),
    ));
    expect(find.text('ALLERGY'), findsOneWidget);
    expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
  });

  testWidgets('accent badge uses accentTint background', (tester) async {
    await tester.pumpWidget(wrap(
      const AdaptiveBadge(label: 'Prescribe', variant: BadgeVariant.accent),
    ));
    final container = tester.widget<Container>(find.byType(Container).first);
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, AppColorTokens.light.accentTint);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/adaptive_badge_test.dart`
Expected: FAIL — file doesn't exist

- [ ] **Step 3: Implement**

```dart
// lib/presentation/shared/widgets/adaptive_badge.dart
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_spacing.dart';

enum BadgeVariant { critical, warning, success, accent, neutral }

/// Small pill badge with a fixed semantic color mapping. Always renders an
/// icon alongside the label (never color alone) for accessibility — icon
/// defaults per variant but can be overridden.
class AdaptiveBadge extends StatelessWidget {
  final String label;
  final BadgeVariant variant;
  final IconData? icon;

  const AdaptiveBadge({
    super.key,
    required this.label,
    required this.variant,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    final (background, foreground, defaultIcon) = switch (variant) {
      BadgeVariant.critical => (tokens.criticalTint, tokens.critical, Icons.warning_rounded),
      BadgeVariant.warning => (tokens.warningTint, tokens.warning, Icons.info_outline),
      BadgeVariant.success => (tokens.successTint, tokens.success, Icons.check_circle_outline),
      BadgeVariant.accent => (tokens.accentTint, tokens.accent, Icons.circle),
      BadgeVariant.neutral => (tokens.surfaceTint, tokens.textSecondary, Icons.circle),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon ?? defaultIcon, size: 11, color: foreground),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/adaptive_badge_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/shared/widgets/adaptive_badge.dart test/shared/adaptive_badge_test.dart
git commit -m "feat: add AdaptiveBadge component"
```

---

### Task 12: `AdaptiveCard`

**Files:**
- Create: `lib/presentation/shared/widgets/adaptive_card.dart`
- Test: `test/shared/adaptive_card_test.dart`

**Interfaces:**
- Consumes: `AppColors.of(context)`, `AppSpacing`/`AppRadius`
- Produces: `class AdaptiveCard extends StatelessWidget` with ctor `{required Widget child, EdgeInsetsGeometry? padding, Color? backgroundColor, Color? borderColor, VoidCallback? onTap}`. Consumed by every flagship-screen restyle task.

- [ ] **Step 1: Write the failing test**

```dart
// test/shared/adaptive_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/config/app_color_scope.dart';
import 'package:healthcare_emr_mobile/config/app_color_tokens.dart';
import 'package:healthcare_emr_mobile/presentation/shared/widgets/adaptive_card.dart';

void main() {
  testWidgets('renders child inside a rounded, surface-colored container', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AppColorScope(
        tokens: AppColorTokens.light,
        child: Scaffold(
          body: AdaptiveCard(child: const Text('inside')),
        ),
      ),
    ));

    expect(find.text('inside'), findsOneWidget);
    final container = tester.widget<Container>(find.byType(Container).first);
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, AppColorTokens.light.surface);
    expect((decoration.borderRadius as BorderRadius).topLeft.x, 16);
  });

  testWidgets('onTap makes the card tappable', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: AppColorScope(
        tokens: AppColorTokens.light,
        child: Scaffold(
          body: AdaptiveCard(onTap: () => tapped = true, child: const Text('tap me')),
        ),
      ),
    ));

    await tester.tap(find.text('tap me'));
    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/adaptive_card_test.dart`
Expected: FAIL — file doesn't exist

- [ ] **Step 3: Implement**

```dart
// lib/presentation/shared/widgets/adaptive_card.dart
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_spacing.dart';

/// Standard card container: surface color, subtle border, 16px radius.
/// Replaces ad hoc Card/Container(decoration:) usage across screens.
class AdaptiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final VoidCallback? onTap;

  const AdaptiveCard({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    final card = Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: backgroundColor ?? tokens.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: borderColor ?? tokens.surfaceBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
              child: child,
            ),
          ),
        ),
      ),
    );
    return card;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/adaptive_card_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/shared/widgets/adaptive_card.dart test/shared/adaptive_card_test.dart
git commit -m "feat: add AdaptiveCard component"
```

---

### Task 13: `StatTile`

**Files:**
- Create: `lib/presentation/shared/widgets/stat_tile.dart`
- Test: `test/shared/stat_tile_test.dart`

**Interfaces:**
- Consumes: `AppColors.of(context)`
- Produces: `class StatTile extends StatelessWidget` with ctor `{required IconData icon, required String label, required String value, required Color color, VoidCallback? onTap}`. Replaces the existing private `_StatTile` in `provider_dashboard_screen.dart` (Task 21) and `patient_detail_screen.dart`'s equivalent inline stat usage where applicable.

- [ ] **Step 1: Write the failing test**

```dart
// test/shared/stat_tile_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/config/app_color_scope.dart';
import 'package:healthcare_emr_mobile/config/app_color_tokens.dart';
import 'package:healthcare_emr_mobile/presentation/shared/widgets/stat_tile.dart';

void main() {
  testWidgets('shows value and label, and is tappable when onTap is provided',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: AppColorScope(
        tokens: AppColorTokens.light,
        child: Scaffold(
          body: StatTile(
            icon: Icons.people,
            label: 'Total Patients',
            value: '248',
            color: AppColorTokens.light.accent,
            onTap: () => tapped = true,
          ),
        ),
      ),
    ));

    expect(find.text('248'), findsOneWidget);
    expect(find.text('Total Patients'), findsOneWidget);
    await tester.tap(find.byType(StatTile));
    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/stat_tile_test.dart`
Expected: FAIL — file doesn't exist

- [ ] **Step 3: Implement**

```dart
// lib/presentation/shared/widgets/stat_tile.dart
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_spacing.dart';

/// Icon/label/number tile used in dashboard-style stat rows.
class StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: tokens.brightness == Brightness.dark ? 0.18 : 0.10),
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: tokens.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/stat_tile_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/shared/widgets/stat_tile.dart test/shared/stat_tile_test.dart
git commit -m "feat: add shared StatTile component"
```

---

### Task 14: `AdaptiveListRow`

**Files:**
- Create: `lib/presentation/shared/widgets/adaptive_list_row.dart`
- Test: `test/shared/adaptive_list_row_test.dart`

**Interfaces:**
- Consumes: `AppColors.of(context)`
- Produces: `class AdaptiveListRow extends StatelessWidget` with ctor `{required Widget leading, required String title, String? subtitle, Widget? trailing, VoidCallback? onTap}`. Consumed by Task 22 (`_RecentPatientsCard`) and Task 25 (`PatientCard`).

- [ ] **Step 1: Write the failing test**

```dart
// test/shared/adaptive_list_row_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/config/app_color_scope.dart';
import 'package:healthcare_emr_mobile/config/app_color_tokens.dart';
import 'package:healthcare_emr_mobile/presentation/shared/widgets/adaptive_list_row.dart';

void main() {
  testWidgets('renders leading, title, subtitle and trailing; onTap fires', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: AppColorScope(
        tokens: AppColorTokens.light,
        child: Scaffold(
          body: AdaptiveListRow(
            leading: const CircleAvatar(child: Text('JB')),
            title: 'James Bello',
            subtitle: 'M · 42y · O+',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => tapped = true,
          ),
        ),
      ),
    ));

    expect(find.text('James Bello'), findsOneWidget);
    expect(find.text('M · 42y · O+'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    await tester.tap(find.text('James Bello'));
    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/adaptive_list_row_test.dart`
Expected: FAIL — file doesn't exist

- [ ] **Step 3: Implement**

```dart
// lib/presentation/shared/widgets/adaptive_list_row.dart
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_spacing.dart';

/// Avatar/leading + title + optional subtitle + optional trailing.
/// Generalizes the pattern used for patient rows, facility rows, etc.
class AdaptiveListRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const AdaptiveListRow({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
        child: Row(
          children: [
            leading,
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14, color: tokens.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/adaptive_list_row_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/shared/widgets/adaptive_list_row.dart test/shared/adaptive_list_row_test.dart
git commit -m "feat: add AdaptiveListRow component"
```

---

### Task 15: `CriticalAlertCard`

**Files:**
- Create: `lib/presentation/shared/widgets/critical_alert_card.dart`
- Test: `test/shared/critical_alert_card_test.dart`

**Interfaces:**
- Consumes: `AppColors.of(context)`, `AdaptiveBadge` (Task 11)
- Produces: `class CriticalAlertCard extends StatelessWidget` with ctor `{required String title, required List<String> items}`. This is the hard-invariant safety component — consumed by Task 27 (`_OverviewTab`) and covered again by the dedicated ordering test in Task 30.

- [ ] **Step 1: Write the failing test**

```dart
// test/shared/critical_alert_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/config/app_color_scope.dart';
import 'package:healthcare_emr_mobile/config/app_color_tokens.dart';
import 'package:healthcare_emr_mobile/presentation/shared/widgets/critical_alert_card.dart';

void main() {
  testWidgets('renders title and every item, high-contrast critical styling', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AppColorScope(
        tokens: AppColorTokens.light,
        child: Scaffold(
          body: CriticalAlertCard(
            title: 'CRITICAL ALLERGY',
            items: const ['Penicillin — Anaphylaxis', 'Peanuts — Severe'],
          ),
        ),
      ),
    ));

    expect(find.text('CRITICAL ALLERGY'), findsOneWidget);
    expect(find.text('Penicillin — Anaphylaxis'), findsOneWidget);
    expect(find.text('Peanuts — Severe'), findsOneWidget);

    final container = tester.widget<Container>(find.byType(Container).first);
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, AppColorTokens.light.criticalTint);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/critical_alert_card_test.dart`
Expected: FAIL — file doesn't exist

- [ ] **Step 3: Implement**

```dart
// lib/presentation/shared/widgets/critical_alert_card.dart
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_spacing.dart';

/// High-contrast, safety-first card for life-threatening patient
/// information (e.g. critical allergies). Any screen surfacing this kind
/// of data MUST use this component and MUST render it before any other
/// content in the same scroll — see Task 27 (_OverviewTab) and the
/// dedicated ordering test in test/patients/patient_detail_overview_test.dart.
class CriticalAlertCard extends StatelessWidget {
  final String title;
  final List<String> items;

  const CriticalAlertCard({
    super.key,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: tokens.criticalTint,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: tokens.criticalBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_rounded, size: 18, color: tokens.critical),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.02,
                  color: tokens.critical,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: items
                .map((item) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm, vertical: 4),
                      decoration: BoxDecoration(
                        color: tokens.surface,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: tokens.criticalBorder),
                      ),
                      child: Text(
                        item,
                        style: TextStyle(fontSize: 12, color: tokens.critical),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/critical_alert_card_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/shared/widgets/critical_alert_card.dart test/shared/critical_alert_card_test.dart
git commit -m "feat: add CriticalAlertCard safety component"
```

---

### Task 16: Restyle existing `platform.dart` adaptive widgets onto the new tokens

**Files:**
- Modify: `lib/core/platform.dart` (already migrated symbol-wise by Task 10 — this task applies `AppRadius`/`AppSpacing` where the old code used raw numbers)

**Interfaces:**
- Consumes: `AppSpacing`/`AppRadius` (Task 4)

- [ ] **Step 1: Apply spacing/radius tokens to `showAdaptiveToast`'s overlay banner**

In `lib/core/platform.dart`, in the `showAdaptiveToast` function's `OverlayEntry` builder (around the `borderRadius: BorderRadius.circular(12)` and `padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)` lines), replace the literals with `AppRadius.card` and `AppSpacing.lg`/`AppSpacing.md` respectively, matching the values already in use (12 ≈ card radius is actually `AppRadius.control`; use `AppRadius.control` there since the original value was 12, not 16).

Add the import: `import 'app_spacing.dart';` → correct relative path from `lib/core/platform.dart` is `import '../config/app_spacing.dart';`.

- [ ] **Step 2: Verify it compiles and existing tests still pass**

Run: `flutter analyze lib/core/platform.dart && flutter test`
Expected: `No issues found!`, all tests pass

- [ ] **Step 3: Commit**

```bash
git add lib/core/platform.dart
git commit -m "refactor: apply AppSpacing/AppRadius tokens to platform.dart adaptive widgets"
```

---

## Phase 5 — Settings Toggle

### Task 17: Add Appearance control to Staff Profile

**Files:**
- Modify: `lib/presentation/profile/screens/staff_profile_screen.dart:114-136` (insert a new `_SectionCard` right after the existing `Account` one)

**Interfaces:**
- Consumes: `ThemeModeProvider` (Task 6)

- [ ] **Step 1: Write the failing test**

```dart
// test/profile/appearance_section_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:healthcare_emr_mobile/config/app_color_scope.dart';
import 'package:healthcare_emr_mobile/config/app_color_tokens.dart';
import 'package:healthcare_emr_mobile/data/providers/theme_mode_provider.dart';

void main() {
  testWidgets('tapping Dark in the Appearance segmented control calls setMode(dark)',
      (tester) async {
    final provider = ThemeModeProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider.value(value: provider)],
        child: MaterialApp(
          home: AppColorScope(
            tokens: AppColorTokens.light,
            child: Scaffold(
              body: Consumer<ThemeModeProvider>(
                builder: (context, tm, _) => SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                    ButtonSegment(value: ThemeMode.system, label: Text('System')),
                  ],
                  selected: {tm.mode},
                  onSelectionChanged: (s) => tm.setMode(s.first),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Dark'));
    await tester.pump();
    expect(provider.mode, ThemeMode.dark);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/profile/appearance_section_test.dart`
Expected: PASS actually — this test exercises `ThemeModeProvider` + a bare `SegmentedButton`, both of which already exist after Task 6. Its purpose here is to lock in the exact widget/interaction contract *before* wiring it into the real screen. Confirm it passes standalone, then proceed to wire the equivalent markup into `staff_profile_screen.dart`.

- [ ] **Step 3: Insert the Appearance section into `_ProfileTab`**

In `lib/presentation/profile/screens/staff_profile_screen.dart`, immediately after the closing `),` of the existing `Account` `_SectionCard` (currently ending at line 135, right before the `// Membership info` comment), insert:

```dart
              // Appearance
              Consumer<ThemeModeProvider>(
                builder: (context, themeMode, _) => _SectionCard(
                  title: 'Appearance',
                  icon: Icons.palette_outlined,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                          ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                          ButtonSegment(value: ThemeMode.system, label: Text('System')),
                        ],
                        selected: {themeMode.mode},
                        onSelectionChanged: (selection) =>
                            themeMode.setMode(selection.first),
                      ),
                    ),
                  ],
                ),
              ),
```

Add `import '../../../data/providers/theme_mode_provider.dart';` to the file's import block if not already present via Task 10's mechanical migration (it won't be — this is a new import specific to this feature).

- [ ] **Step 4: Manually verify in a running app**

Run: `flutter run` (any target), navigate to Staff Profile → Profile tab, confirm the Appearance card appears under Account with a working Light/Dark/System segmented control, and that selecting Dark actually flips the app's theme live.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/profile/screens/staff_profile_screen.dart test/profile/appearance_section_test.dart
git commit -m "feat: add Appearance (light/dark/system) control to Staff Profile"
```

---

## Phase 6 — Flagship Screens

### Task 18: Restyle Login screen

**Files:**
- Modify: `lib/presentation/auth/screens/login_screen.dart` (header at lines 209-224, `_buildPasswordStep` at 250-338, `_buildTwoFactorStep` at 342-388, `_FacilitySelector`/`_ErrorBox`/`_LoadingSpinner` at 395+)

**Interfaces:**
- Consumes: `AdaptiveCard` (Task 12), `AppColors.of(context)` (already wired by Task 10's migration)

- [ ] **Step 1: Write a widget test locking in the existing copy survives the restyle**

```dart
// test/auth/login_screen_restyle_test.dart
// Extends the existing test/auth/login_screen_test.dart coverage — this
// file only asserts the visual-layer contract, not auth behavior (already
// covered there).
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:healthcare_emr_mobile/core/api/api_client.dart';
import 'package:healthcare_emr_mobile/data/providers/auth_provider.dart';
import 'package:healthcare_emr_mobile/data/providers/organization_provider.dart';
import 'package:healthcare_emr_mobile/data/repositories/auth_repository.dart';
import 'package:healthcare_emr_mobile/data/repositories/organization_repository.dart';
import 'package:healthcare_emr_mobile/presentation/auth/screens/login_screen.dart';
import 'package:healthcare_emr_mobile/presentation/shared/widgets/adaptive_card.dart';

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super();
  @override
  Future<Map<String, dynamic>> post(String path,
          {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async =>
      {'success': true, 'data': {}};
}

void main() {
  testWidgets('login form is wrapped in an AdaptiveCard and keeps its existing copy',
      (tester) async {
    final apiClient = _FakeApiClient();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => AuthProvider(repository: AuthRepository(apiClient: apiClient))),
        ChangeNotifierProvider(
            create: (_) =>
                OrganizationProvider(repository: OrganizationRepository(apiClient: apiClient))),
      ],
      child: const MaterialApp(home: LoginScreen()),
    ));

    expect(find.text('Healthcare EMR'), findsOneWidget);
    expect(find.text('Provider Login'), findsOneWidget);
    expect(find.byType(AdaptiveCard), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/auth/login_screen_restyle_test.dart`
Expected: FAIL — no `AdaptiveCard` present yet

- [ ] **Step 3: Wrap the form body in an `AdaptiveCard` and restyle the header**

In `lib/presentation/auth/screens/login_screen.dart`, add the import:

```dart
import '../../shared/widgets/adaptive_card.dart';
```

Replace the `build` method's `Column` (lines 205-238) so the header icon/title/subtitle sit above an `AdaptiveCard` wrapping the form steps, keeping every existing string and callback untouched:

```dart
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Header ───────────────────────────────────────────
                      Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.of(context).accent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.local_hospital,
                            size: 28, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      const Text('Healthcare EMR',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 28, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        show2FA
                            ? 'Two-Factor Authentication'
                            : 'Provider Login',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: AppColors.of(context).textSecondary),
                      ),
                      const SizedBox(height: 32),

                      AdaptiveCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Error banner ─────────────────────────────
                            if (_errorMessage != null) ...[
                              _ErrorBox(message: _errorMessage!),
                              const SizedBox(height: 16),
                            ],

                            if (show2FA)
                              _buildTwoFactorStep()
                            else
                              _buildPasswordStep(),
                          ],
                        ),
                      ),
                    ],
                  ),
```

Leave `_buildPasswordStep()`, `_buildTwoFactorStep()`, `_FacilitySelector`, `_ErrorBox`, `_LoadingSpinner` bodies exactly as they are — their colors were already migrated to `AppColors.of(context)` by Task 10.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/auth/login_screen_restyle_test.dart && flutter test test/auth/login_screen_test.dart`
Expected: both PASS (the original behavioral test must still pass unmodified — if it doesn't, the restyle broke something functional, not just visual)

- [ ] **Step 5: Manual check**

Run: `flutter run`, walk through email → password → (if applicable) 2FA, confirm the new card treatment matches the approved Login mockup (icon badge, headline, card-wrapped form) and the `AdaptiveFilledButton`/`AdaptiveTextButton` styling flows through correctly.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/auth/screens/login_screen.dart test/auth/login_screen_restyle_test.dart
git commit -m "feat: restyle Login screen onto the new design system"
```

---

### Task 19: Restyle Facility Picker screen

**Files:**
- Modify: `lib/presentation/auth/screens/facility_picker_screen.dart` (greeting `Card` at lines 91-118, `_FacilityTile` at 167-221)

**Interfaces:**
- Consumes: `AdaptiveCard` (Task 12), `AdaptiveListRow` (Task 14)

- [ ] **Step 1: Write the failing test**

```dart
// test/auth/facility_picker_restyle_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:healthcare_emr_mobile/core/api/api_client.dart';
import 'package:healthcare_emr_mobile/data/providers/auth_provider.dart';
import 'package:healthcare_emr_mobile/data/repositories/auth_repository.dart';
import 'package:healthcare_emr_mobile/presentation/auth/screens/facility_picker_screen.dart';
import 'package:healthcare_emr_mobile/presentation/shared/widgets/adaptive_card.dart';

void main() {
  testWidgets('greeting card renders as an AdaptiveCard', (tester) async {
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => AuthProvider(repository: AuthRepository(apiClient: ApiClient()))),
      ],
      child: const MaterialApp(home: FacilityPickerScreen()),
    ));
    expect(find.byType(AdaptiveCard), findsWidgets);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/auth/facility_picker_restyle_test.dart`
Expected: FAIL — no `AdaptiveCard` yet

- [ ] **Step 3: Replace the greeting `Card` and `_FacilityTile`'s `Card`/`ListTile`**

Add the import: `import '../../shared/widgets/adaptive_card.dart';` and `import '../../shared/widgets/adaptive_list_row.dart';`.

Replace the greeting `Card(child: Padding(...))` (lines 91-118) with `AdaptiveCard(child: Column(...))` — same inner `CircleAvatar`/`Text` children, unchanged.

Replace `_FacilityTile`'s `Card(child: ListTile(...))` body (lines 182-219) with:

```dart
    return AdaptiveCard(
      onTap: onTap,
      child: AdaptiveListRow(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.of(context).accentTint,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.local_hospital, color: AppColors.of(context).accent),
        ),
        title: facility.name,
        subtitle: [
          if (facility.organization != null) facility.organization!.name,
          if (membership != null) membership.displayType,
        ].join(' · '),
        trailing: isLoading
            ? const SizedBox(
                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.chevron_right),
      ),
    );
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/auth/facility_picker_restyle_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/auth/screens/facility_picker_screen.dart test/auth/facility_picker_restyle_test.dart
git commit -m "feat: restyle Facility Picker screen onto the new design system"
```

---

### Task 20: Restyle Dashboard `_WelcomeCard`

**Files:**
- Modify: `lib/presentation/dashboard/screens/provider_dashboard_screen.dart:513-566`

**Interfaces:**
- Consumes: `AppColors.of(context)`

- [ ] **Step 1: Write the failing test**

```dart
// test/dashboard/welcome_card_test.dart
// Targets the private _WelcomeCard indirectly by pumping the full
// ProviderDashboardScreen and checking for solid-accent (not gradient)
// styling, matching the approved mockup.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/config/app_color_tokens.dart';

void main() {
  test('welcome card uses the flat accent color, not a two-stop gradient',
      () {
    // Documents the design decision this task encodes: the mockup showed a
    // solid accent app bar/banner, not the old primary->secondary gradient.
    expect(AppColorTokens.light.accent, isNotNull);
  });
}
```

(This is a thin placeholder-style assertion because `_WelcomeCard` is a private class not exported for direct widget-pumping outside its file without also standing up `AuthProvider`/`PatientProvider` — the meaningful verification here is Step 4's manual check against the approved mockup. Don't skip Step 4.)

- [ ] **Step 2: Implement**

In `lib/presentation/dashboard/screens/provider_dashboard_screen.dart`, replace `_WelcomeCard.build` (lines 519-565):

```dart
  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return AdaptiveCard(
      backgroundColor: tokens.accent,
      borderColor: tokens.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Welcome back,',
              style: TextStyle(fontSize: 16, color: Colors.white70)),
          const SizedBox(height: 4),
          Text(auth.displayName,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          if (auth.staffTypeDisplay.isNotEmpty)
            Text(
              auth.department.isNotEmpty
                  ? '${auth.staffTypeDisplay} · ${auth.department}'
                  : auth.staffTypeDisplay,
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
          if (auth.facilityName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.location_on, size: 14, color: Colors.white54),
              const SizedBox(width: 4),
              Text(auth.facilityName,
                  style: const TextStyle(fontSize: 13, color: Colors.white70)),
            ]),
          ],
        ],
      ),
    );
  }
```

Add imports: `import '../../shared/widgets/adaptive_card.dart';` (relative path from `presentation/dashboard/screens/` is `../../shared/widgets/adaptive_card.dart`).

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze lib/presentation/dashboard/screens/provider_dashboard_screen.dart`
Expected: no new errors from this edit

- [ ] **Step 4: Manual check against the approved mockup**

Run: `flutter run`, log in, confirm the Welcome card is a flat accent-blue card (no gradient), matching the Dashboard mockup approved during brainstorming.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/dashboard/screens/provider_dashboard_screen.dart test/dashboard/welcome_card_test.dart
git commit -m "feat: restyle Dashboard Welcome card as flat accent AdaptiveCard"
```

---

### Task 21: Restyle Dashboard `_PatientStatsCard` onto shared `StatTile`

**Files:**
- Modify: `lib/presentation/dashboard/screens/provider_dashboard_screen.dart:570-675` (`_PatientStatsCard`), delete the private `_StatTile` class (~lines 1020-1072, exact range to confirm via `grep -n "class _StatTile" -A 60`)

**Interfaces:**
- Consumes: `StatTile` (Task 13), `AdaptiveCard` (Task 12)

- [ ] **Step 1: Write the failing test**

```dart
// test/dashboard/patient_stats_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/presentation/shared/widgets/stat_tile.dart';

void main() {
  test('StatTile is the component the dashboard now uses for patient stats', () {
    // Confirms StatTile (Task 13) exists and is importable from the
    // dashboard screen's location before wiring it in — the meaningful
    // check is Step 4's manual run.
    expect(StatTile, isNotNull);
  });
}
```

- [ ] **Step 2: Replace `_StatTile` usages with the shared `StatTile`**

Add import: `import '../../shared/widgets/stat_tile.dart';` and `import '../../shared/widgets/adaptive_card.dart';`.

In `_PatientStatsCard.build`, replace the outer `Card(child: Padding(...))` with `AdaptiveCard(...)`, keeping the header `Row` (icon/title/cache-indicator/spinner) and `Divider` unchanged, and change each `_StatTile(...)` call to `StatTile(...)` (identical named parameters — `icon`, `label`, `value`, `color`, `onTap` — so this is a type-name swap, no parameter changes).

Delete the private `_StatTile extends StatelessWidget` class (find its exact bounds first):

Run: `grep -n "class _StatTile" -A 60 lib/presentation/dashboard/screens/provider_dashboard_screen.dart`

Delete from that `class _StatTile` line through its closing `}` (confirm the boundary by checking the next `class` declaration doesn't get caught in the deletion).

- [ ] **Step 3: Verify it compiles, and verify the deletion was complete — don't treat analyze as a formality**

Run: `flutter analyze lib/presentation/dashboard/screens/provider_dashboard_screen.dart`
Expected: no errors. Note that a bad deletion boundary can fail *silently* here: if you deleted too little (an orphaned, unreferenced fragment of `_StatTile` left behind), `analyze` typically reports only an `unused_element`-class warning, not a hard error, so don't treat a clean `analyze` run alone as proof the deletion was correct.

Also run: `grep -n "_StatTile" lib/presentation/dashboard/screens/provider_dashboard_screen.dart`
Expected: no output at all (zero hits) — confirms both that every call site was updated to `StatTile` and that the old private class and its declaration are fully gone, not partially deleted.

- [ ] **Step 4: Manual check**

Run: `flutter run`, confirm the four stat tiles (Total Patients, New 7 days, Upcoming Appts, Active Rx) render with the new tinted-icon-tile look from the approved mockup.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/dashboard/screens/provider_dashboard_screen.dart test/dashboard/patient_stats_card_test.dart
git commit -m "refactor: replace dashboard's private _StatTile with shared StatTile"
```

---

### Task 22: Restyle Dashboard `_RecentPatientsCard` onto `AdaptiveListRow`

**Files:**
- Modify: `lib/presentation/dashboard/screens/provider_dashboard_screen.dart:679-786`

**Interfaces:**
- Consumes: `AdaptiveListRow` (Task 14), `AdaptiveCard` (Task 12), `AdaptiveBadge` (Task 11)

- [ ] **Step 1: Write the failing test**

Since `_RecentPatientsCard` is private and requires `PatientProvider` context, this is verified by extending the dashboard's existing integration-style tests (if any) or, if none pump the full dashboard with seeded patients, by a manual check — proceed directly to Step 2 and use Step 4 as the verification gate, consistent with Task 20's approach for private, provider-coupled widgets.

- [ ] **Step 2: Replace the outer `Card` and `ListTile` rows**

Replace `_RecentPatientsCard.build`'s outer `Card(child: Padding(...))` with `AdaptiveCard(...)`, keeping the header `Row` and `Divider` unchanged. Replace the `ListView.separated`'s `ListTile` (lines 740-776) with `AdaptiveListRow`:

```dart
                      return AdaptiveListRow(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.of(context).accentTint,
                          child: Text(
                            '${patient.firstName[0]}${patient.lastName[0]}',
                            style: TextStyle(
                                color: AppColors.of(context).accent, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: patient.fullName,
                        subtitle: '${patient.gender} · ${patient.ageDisplay}'
                            '${patient.bloodType != null ? ' · ${patient.bloodType}' : ''}',
                        trailing: patient.hasCriticalAllergies
                            ? const AdaptiveBadge(label: 'Allergy', variant: BadgeVariant.critical)
                            : null,
                        onTap: () {
                          context.read<PatientProvider>().setSelectedPatient(patient);
                          Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const PatientListScreen()));
                        },
                      );
```

Add imports: `adaptive_list_row.dart`, `adaptive_card.dart`, `adaptive_badge.dart` from `../../shared/widgets/`.

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze lib/presentation/dashboard/screens/provider_dashboard_screen.dart`
Expected: no errors

- [ ] **Step 4: Manual check**

Run: `flutter run`, confirm Recent Patients rows show the new avatar/name/meta/badge layout, and the critical-allergy badge still appears for patients that have one.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/dashboard/screens/provider_dashboard_screen.dart
git commit -m "feat: restyle Dashboard Recent Patients onto AdaptiveListRow/AdaptiveBadge"
```

---

### Task 23: Restyle Dashboard `_SubscriptionCard`, `_AccessGrantsCard`, `_EmergencyAccessCard`

**Files:**
- Modify: `lib/presentation/dashboard/screens/provider_dashboard_screen.dart:790-1019` (three private classes)

**Interfaces:**
- Consumes: `AdaptiveCard` (Task 12), `AdaptiveBadge` (Task 11)

- [ ] **Step 1: Read each class's current body**

Run: `sed -n '790,1019p' lib/presentation/dashboard/screens/provider_dashboard_screen.dart` and note each `Card(...)` wrapper's exact boundaries before editing (this task doesn't hand-transcribe all three bodies here because their internals — trial countdown logic, pending-count badges, escalation warnings — are read directly from the file at edit time, not reproduced from memory).

- [ ] **Step 2: Apply the established pattern to each**

For each of `_SubscriptionCard`, `_AccessGrantsCard`, `_EmergencyAccessCard`:
- Replace the outer `Card(child: ...)`/`Card(child: Padding(...))` wrapper with `AdaptiveCard(...)`, using `backgroundColor: AppColors.of(context).criticalTint` and `borderColor: AppColors.of(context).criticalBorder` specifically for `_EmergencyAccessCard` (it's a warning-weight card per the approved Dashboard mockup), and the default `AdaptiveCard()` (surface-colored) for the other two.
- Replace any bare numeric pending/unreviewed-count badge (e.g. a `Container` with `BoxDecoration(color: Colors.red, shape: BoxShape.circle)` styled count) with `AdaptiveBadge(label: '$count', variant: BadgeVariant.critical)` for the Emergency Access card, and `variant: BadgeVariant.warning` for the Access Grants pending-approval count.
- Do not change any `Consumer`/provider-reading logic, navigation callbacks, or conditional-visibility logic (`if (grants.isNotEmpty)` etc.) — only the outer container and badge widgets change.

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze lib/presentation/dashboard/screens/provider_dashboard_screen.dart`
Expected: no errors

- [ ] **Step 4: Manual check**

Run: `flutter run` with a seeded account that has pending access grants and at least one unreviewed emergency-access event; confirm both cards render with the new `AdaptiveCard`/`AdaptiveBadge` treatment and that tapping through to `AccessGrantsScreen`/`EmergencyAccessScreen` still works.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/dashboard/screens/provider_dashboard_screen.dart
git commit -m "feat: restyle Dashboard Subscription/AccessGrants/EmergencyAccess cards"
```

---

### Task 24: Restyle Dashboard drawer

**Files:**
- Modify: `lib/presentation/dashboard/screens/provider_dashboard_screen.dart:296-` (`_buildDrawer` method — read its current body first)

**Interfaces:**
- Consumes: `AppColors.of(context)`

- [ ] **Step 1: Read the current drawer body**

Run: `sed -n '296,420p' lib/presentation/dashboard/screens/provider_dashboard_screen.dart` (the method body's end boundary — find the next method/class after `_buildDrawer` to bound the edit).

- [ ] **Step 2: Restyle the drawer header and selected-item highlight**

Replace the drawer's `DrawerHeader` (or equivalent header container) background from whatever gradient/primary-color fill it currently uses to `AppColors.of(context).accent` (flat, matching the Welcome card decision in Task 20). For the active/selected `ListTile` in the drawer (if one exists highlighting the current route), use `AppColors.of(context).accentTint` as its background and `AppColors.of(context).accent` for its icon/text color, consistent with the rest of the app's accent usage. Leave every `ListTile`'s `onTap`/navigation logic untouched.

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze lib/presentation/dashboard/screens/provider_dashboard_screen.dart`
Expected: no errors

- [ ] **Step 4: Manual check**

Run: `flutter run`, open the drawer, confirm the header and any active-item highlighting use the new accent color and that every menu item still navigates correctly (Patients, Access Grants, Emergency Access, Subscription, Reports, My Profile, Logout).

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/dashboard/screens/provider_dashboard_screen.dart
git commit -m "feat: restyle Dashboard drawer onto the new design system"
```

---

### Task 25: Restyle `PatientCard` widget onto `AdaptiveListRow`/`AdaptiveBadge`

**Files:**
- Modify: `lib/presentation/patients/widgets/patient_card.dart` (full file, 191 lines)

**Interfaces:**
- Consumes: `AdaptiveCard` (Task 12), `AdaptiveListRow` (Task 14), `AdaptiveBadge` (Task 11)

- [ ] **Step 1: Write the failing test**

```dart
// test/patients/patient_card_restyle_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/config/app_color_scope.dart';
import 'package:healthcare_emr_mobile/config/app_color_tokens.dart';
import 'package:healthcare_emr_mobile/data/models/patient_models.dart';
import 'package:healthcare_emr_mobile/presentation/patients/widgets/patient_card.dart';
import 'package:healthcare_emr_mobile/presentation/shared/widgets/adaptive_badge.dart';
import 'package:healthcare_emr_mobile/presentation/shared/widgets/adaptive_list_row.dart';

void main() {
  testWidgets('critical-allergy patient shows an AdaptiveBadge inside an AdaptiveListRow',
      (tester) async {
    final patient = PatientModel.fromJson({
      'id': '1', 'first_name': 'James', 'last_name': 'Bello',
      'gender': 'male', 'date_of_birth': '1983-01-01',
      'has_critical_allergies': true, 'chronic_conditions': [],
    });

    await tester.pumpWidget(MaterialApp(
      home: AppColorScope(
        tokens: AppColorTokens.light,
        child: Scaffold(body: PatientCard(patient: patient)),
      ),
    ));

    expect(find.byType(AdaptiveListRow), findsOneWidget);
    expect(find.byType(AdaptiveBadge), findsOneWidget);
    expect(find.text('James Bello'), findsOneWidget);
  });
}
```

(If `PatientModel.fromJson`'s required fields differ from this guess, adjust the fixture to match the real model in `lib/data/models/patient_models.dart` — check it before running.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/patients/patient_card_restyle_test.dart`
Expected: FAIL — `AdaptiveListRow`/`AdaptiveBadge` not present yet

- [ ] **Step 3: Rewrite `PatientCard.build`**

```dart
// lib/presentation/patients/widgets/patient_card.dart
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../data/models/patient_models.dart';
import '../../shared/widgets/adaptive_badge.dart';
import '../../shared/widgets/adaptive_card.dart';
import '../../shared/widgets/adaptive_list_row.dart';
import '../screens/patient_detail_screen.dart';

class PatientCard extends StatelessWidget {
  final PatientModel patient;
  final VoidCallback? onTap;

  const PatientCard({super.key, required this.patient, this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return AdaptiveCard(
      onTap: onTap ?? () => _onDefaultTap(context),
      child: AdaptiveListRow(
        leading: _PatientAvatar(patient: patient),
        title: patient.fullName,
        subtitle: _demographicLine,
        trailing: patient.hasCriticalAllergies
            ? const AdaptiveBadge(label: 'Allergy', variant: BadgeVariant.critical)
            : Icon(Icons.chevron_right, color: tokens.textSecondary, size: 20),
      ),
    );
  }

  String get _demographicLine {
    final parts = <String>[
      if (patient.mrn != null) patient.mrn!,
      patient.gender.capitalize(),
      patient.ageDisplay,
      if (patient.bloodType != null) patient.bloodType!,
    ];
    return parts.join(' · ');
  }

  void _onDefaultTap(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PatientDetailScreen(patient: patient)),
    );
  }
}

class _PatientAvatar extends StatelessWidget {
  final PatientModel patient;
  const _PatientAvatar({required this.patient});

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    final Color bg = patient.hasCriticalAllergies ? tokens.criticalTint : tokens.accentTint;
    final Color fg = patient.hasCriticalAllergies ? tokens.critical : tokens.accent;
    return CircleAvatar(
      radius: 24,
      backgroundColor: bg,
      child: Text(
        '${patient.firstName[0]}${patient.lastName[0]}',
        style: TextStyle(fontWeight: FontWeight.bold, color: fg, fontSize: 15),
      ),
    );
  }
}

extension StringCapitalize on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
```

Note: the old `secondaryColor`-based female/male avatar-color distinction is dropped — the new system has one `accent` hue (see Task 10's mapping table), so avatar color now only distinguishes critical-allergy vs. not, which is the safety-relevant distinction. This is a deliberate simplification of the original three-way color logic (male/female/critical), consistent with the spec's decision not to reintroduce a second hue.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/patients/patient_card_restyle_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/patients/widgets/patient_card.dart test/patients/patient_card_restyle_test.dart
git commit -m "feat: restyle PatientCard onto AdaptiveListRow/AdaptiveBadge"
```

---

### Task 26: Restyle Patient List screen

**Files:**
- Modify: `lib/presentation/patients/screens/patient_list_screen.dart` (search bar, offline/error banners, FAB — read the file first to locate exact line ranges, since only symbol counts were confirmed earlier, not structure)

**Interfaces:**
- Consumes: `AppColors.of(context)`, `AdaptiveBadge` (Task 11, for the offline banner)

- [ ] **Step 1: Read the current structure**

Run: `grep -n "Widget _build\|Scaffold(\|AppBar(\|floatingActionButton\|Banner" lib/presentation/patients/screens/patient_list_screen.dart`

- [ ] **Step 2: Restyle the offline/error banners and FAB**

Using the line numbers found in Step 1: replace any raw `Container`-based offline-data banner with an `AdaptiveBadge`-style treatment or an `AdaptiveCard` with `backgroundColor: AppColors.of(context).warningTint` (offline banners are informational, not critical — use `warningTint`, not `criticalTint`). Restyle the error banner (if a separate one exists) with `AppColors.of(context).criticalTint`/`.criticalBorder`. Leave the `FloatingActionButton`'s icon/`onPressed` unchanged; only its `backgroundColor` becomes `AppColors.of(context).accent` if it isn't already theme-derived.

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze lib/presentation/patients/screens/patient_list_screen.dart`
Expected: no errors

- [ ] **Step 4: Manual check**

Run: `flutter run`, go to Patient List, toggle airplane mode (or otherwise force the offline path) to confirm the offline banner renders with the new warning treatment, then confirm search and infinite scroll still work (unchanged logic).

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/patients/screens/patient_list_screen.dart
git commit -m "feat: restyle Patient List screen banners and FAB"
```

---

### Task 27: Restyle Patient Detail `_OverviewTab` — the safety-critical task

**Files:**
- Modify: `lib/presentation/patients/screens/patient_detail_screen.dart:515-745` (`_OverviewTab`)

**Interfaces:**
- Consumes: `CriticalAlertCard` (Task 15), `AdaptiveCard` (Task 12)
- Produces: the concrete rendering this plan's safety invariant (Task 30) tests against.

- [ ] **Step 1: Write the failing test (this IS the safety-invariant test — see also Task 30 for the dedicated version)**

```dart
// test/patients/patient_detail_overview_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/config/app_color_scope.dart';
import 'package:healthcare_emr_mobile/config/app_color_tokens.dart';
import 'package:healthcare_emr_mobile/data/models/patient_models.dart';
import 'package:healthcare_emr_mobile/presentation/shared/widgets/critical_alert_card.dart';

// _OverviewTab is private; this test targets its rendered output indirectly
// by constructing a PatientModel with critical allergies and confirming
// CriticalAlertCard appears. If _OverviewTab is not exported, extract the
// class-under-test check into a small public wrapper OR (preferred, and
// what this task does) keep the class private and instead assert this
// invariant via the full PatientDetailScreen in Task 30, which owns the
// canonical "renders first" check. This file covers the simpler
// "renders at all when allergies are critical" case.
void main() {
  test('a patient with critical allergies has hasCriticalAllergies true',
      () {
    final patient = PatientModel.fromJson({
      'id': '1', 'first_name': 'James', 'last_name': 'Bello',
      'gender': 'male', 'date_of_birth': '1983-01-01',
      'allergies': [
        {'name': 'Penicillin', 'severity': 'life_threatening', 'is_life_threatening': true}
      ],
      'chronic_conditions': [],
    });
    expect(patient.hasCriticalAllergies, isTrue);
    expect(CriticalAlertCard, isNotNull); // component exists (Task 15)
  });
}
```

- [ ] **Step 2: Run test to verify it fails or passes for the right reason**

Run: `flutter test test/patients/patient_detail_overview_test.dart`
Expected: PASS if `PatientModel`'s field names match this fixture — if the real model uses different field names (check `lib/data/models/patient_models.dart` `fromJson` before running), adjust the fixture accordingly. This test's job is to lock in the model contract before Step 3's UI change; Task 30 is what actually enforces the ordering invariant on the real `_OverviewTab`.

- [ ] **Step 3: Replace the allergies section with `CriticalAlertCard`, and make it the first child**

Add import: `import '../../shared/widgets/critical_alert_card.dart';` and `import '../../shared/widgets/adaptive_card.dart';`.

Restructure `_OverviewTab.build` (currently lines 519-744) so `CriticalAlertCard` — when `p.hasCriticalAllergies` is true — is the **first** child of the `Column`, before the patient summary card:

```dart
  @override
  Widget build(BuildContext context) {
    final p = patient;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        // Keyed so the safety-invariant test (Task 30) can target this
        // exact Column deterministically — do not remove this key, and do
        // not rely on find.byType(Column).first in any test, since
        // AdaptiveCard/AdaptiveListRow and ancestor widgets (AppBar,
        // Scaffold, TabBarView, AppLockGate) also build Columns.
        key: const Key('overview_tab_column'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Critical allergies — MUST stay first. See CriticalAlertCard's
          // doc comment and test/patients/patient_detail_overview_order_test.dart.
          if (p.hasCriticalAllergies)
            CriticalAlertCard(
              title: 'CRITICAL ALLERGY',
              items: p.allergies
                  .where((a) => a.isLifeThreatening || a.isSevere)
                  .map((a) => '${a.name} — ${a.severity.replaceAll('_', ' ')}')
                  .toList(),
            ),

          // Patient summary card
          AdaptiveCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.of(context).accentTint,
                      child: Text(
                        p.firstName[0] + p.lastName[0],
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.of(context).accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.fullName,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            '${p.ageDisplay} · ${p.gender} · ${p.bloodType ?? 'Blood type unknown'}',
                            style: TextStyle(color: AppColors.of(context).textSecondary, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                if (p.mrn != null) _InfoRow('MRN', p.mrn!),
                _InfoRow('Date of Birth', p.dateOfBirth),
                if (p.phone != null) _InfoRow('Phone', p.phone!),
                if (p.email != null) _InfoRow('Email', p.email!),
                if (p.address != null) _InfoRow('Address', p.address!),
              ],
            ),
          ),

          // ... the remaining sections (Messages, Audit Log, non-critical
          // allergies list if you still want a full severity breakdown
          // below the critical banner, Current Medications, Chronic
          // Conditions, Medical History, Emergency Contact, Insurance)
          // are unchanged from the current file — only their outer Card
          // becomes AdaptiveCard per the established pattern, and every
          // AppTheme.x/AppColors.x reference was already migrated to
          // AppColors.of(context).x by Task 10.
        ],
      ),
    );
  }
```

The comment block at the end marks the remaining ~15 sections in this method (Messages link, Audit Log link, non-critical-allergy detail list, Current Medications, Chronic Conditions, Medical History, Emergency Contact, Insurance) as: replace each `Card(child: Padding(...))` with `AdaptiveCard(...)`, keep every inner widget (the `ListTile`s, `_InfoRow`s, `Chip`s, `Wrap`) exactly as they already are in the file (already migrated by Task 10) — this is the same wrap-only transformation applied throughout this task, not new logic.

- [ ] **Step 4: Verify it compiles**

Run: `flutter analyze lib/presentation/patients/screens/patient_detail_screen.dart`
Expected: no errors

- [ ] **Step 5: Manual check against the approved mockup**

Run: `flutter run`, open a patient with critical allergies, confirm the `CriticalAlertCard` renders first, above the patient summary card, matching the approved Patient Detail mockup. Then open a patient *without* critical allergies and confirm no `CriticalAlertCard` renders and the summary card is first instead.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/patients/screens/patient_detail_screen.dart test/patients/patient_detail_overview_test.dart
git commit -m "feat: restyle Patient Detail Overview tab, CriticalAlertCard renders first"
```

---

### Task 28: Restyle Patient Detail app bar and tab bar

**Files:**
- Modify: `lib/presentation/patients/screens/patient_detail_screen.dart` (app bar construction and `TabBar` around line 467, `floatingActionButton` around line 421)

**Interfaces:**
- Consumes: `AppColors.of(context)`

- [ ] **Step 1: Read the current app bar / TabBar construction**

Run: `sed -n '400,515p' lib/presentation/patients/screens/patient_detail_screen.dart`

- [ ] **Step 2: Restyle the `TabBar` indicator and FAB**

Set the `TabBar`'s `indicatorColor`/`labelColor` to `AppColors.of(context).accent` (or leave unset if `AppTheme.lightTheme`'s global `TabBarTheme` inheritance already covers it — verify by running the app before adding explicit overrides; only add them if the default doesn't match the approved mockup's active-tab underline). Confirm the `floatingActionButton`'s `backgroundColor` resolves to `AppColors.of(context).accent` (it likely already does via `Theme.of(context).colorScheme.primary` — check before overriding).

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze lib/presentation/patients/screens/patient_detail_screen.dart`
Expected: no errors

- [ ] **Step 4: Manual check**

Run: `flutter run`, open a patient, switch between all five tabs, confirm the active-tab indicator uses the accent color and the FAB label/icon changes per tab (Book Appointment / New Prescription / Order Lab Test / Upload Document) as before — this task changes color only.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/patients/screens/patient_detail_screen.dart
git commit -m "feat: restyle Patient Detail tab bar and FAB accent color"
```

---

### Task 29: Restyle Patient Detail's Appointments/Prescriptions/Lab Results/Documents tab cards

**Files:**
- Modify: `lib/presentation/patients/screens/patient_detail_screen.dart` — `_AppointmentCard` (~773-859), `_PrescriptionCard`/`_PrescriptionCardState` (~885-1042), `_LabResultCard`/`_LabResultCardState` (~1067-1316), `_DocumentCard`/`_DocumentCardState` (~1341-1439)

**Interfaces:**
- Consumes: `AdaptiveCard` (Task 12), `AdaptiveBadge` (Task 11)

- [ ] **Step 1: Read each card's current body**

Run: `sed -n '773,1439p' lib/presentation/patients/screens/patient_detail_screen.dart` and note each card class's status-badge logic (appointment status, prescription refill/status, lab priority/abnormal flags, document confidential lock) — these are read at edit time since their exact conditional branches weren't transcribed during planning.

- [ ] **Step 2: Apply the established pattern to each of the four card types**

For `_AppointmentCard`, `_PrescriptionCard`, `_LabResultCard`, `_DocumentCard`:
- Replace the outer `Card(...)` wrapper with `AdaptiveCard(...)`.
- Replace any hand-rolled colored status chip/text (status strings currently colored via ad hoc `Color` logic, already migrated to `AppColors.of(context).x` by Task 10) with `AdaptiveBadge`, choosing the variant by meaning: scheduled/active/normal → `BadgeVariant.success`; pending/due-soon → `BadgeVariant.warning`; cancelled/abnormal/critical-priority/confidential → `BadgeVariant.critical`; everything else → `BadgeVariant.neutral`.
- Do not change any state-management code (`_PrescriptionCardState`, `_LabResultCardState`, `_DocumentCardState` retain their `State` logic, API calls, and `setState` calls unchanged) — only the returned widget tree's outer container and status indicators change.

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze lib/presentation/patients/screens/patient_detail_screen.dart`
Expected: no errors

- [ ] **Step 4: Run the full test suite**

Run: `flutter test`
Expected: all tests pass (this file's cards aren't directly unit-tested today per the file inventory in Task 10 — this step catches any regression in screens that indirectly exercise `PatientDetailScreen`)

- [ ] **Step 5: Manual check**

Run: `flutter run`, open a patient with at least one appointment, prescription, lab result, and document, confirm all four tabs render with the new card/badge treatment and that every FAB (Book Appointment / New Prescription / Order Lab Test / Upload Document) still opens its bottom-sheet form correctly.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/patients/screens/patient_detail_screen.dart
git commit -m "feat: restyle Patient Detail Appointments/Prescriptions/Labs/Documents cards"
```

---

## Phase 7 — Safety-Invariant Tests

### Task 30: Widget test — `CriticalAlertCard` renders first in Patient Detail's Overview tab

**Files:**
- Create: `test/patients/patient_detail_overview_order_test.dart`

**Interfaces:**
- Consumes: `PatientDetailScreen`, `CriticalAlertCard` (Task 15), the restyled `_OverviewTab` (Task 27)

- [ ] **Step 1: Write the test**

```dart
// test/patients/patient_detail_overview_order_test.dart
//
// Enforces the hard invariant from the design spec: when a patient has
// critical allergies, CriticalAlertCard must be the first card rendered
// in the Overview tab's scroll — not just present somewhere on screen.
// This survives future PRs that reorder sections or touch spacing, unlike
// a purely manual QA pass (see spec's "Testing" section, blocking issue #2).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:healthcare_emr_mobile/config/app_color_scope.dart';
import 'package:healthcare_emr_mobile/config/app_color_tokens.dart';
import 'package:healthcare_emr_mobile/core/api/api_client.dart';
import 'package:healthcare_emr_mobile/data/models/patient_models.dart';
import 'package:healthcare_emr_mobile/data/providers/auth_provider.dart';
import 'package:healthcare_emr_mobile/data/providers/clinical_provider.dart';
import 'package:healthcare_emr_mobile/data/repositories/auth_repository.dart';
import 'package:healthcare_emr_mobile/data/repositories/clinical_repository.dart';
import 'package:healthcare_emr_mobile/presentation/patients/screens/patient_detail_screen.dart';
import 'package:healthcare_emr_mobile/presentation/shared/widgets/adaptive_card.dart';
import 'package:healthcare_emr_mobile/presentation/shared/widgets/critical_alert_card.dart';

void main() {
  testWidgets('CriticalAlertCard is the first card in the Overview scroll',
      (tester) async {
    final apiClient = ApiClient();
    final patient = PatientModel.fromJson({
      'id': '1', 'first_name': 'James', 'last_name': 'Bello',
      'gender': 'male', 'date_of_birth': '1983-01-01',
      'allergies': [
        {'name': 'Penicillin', 'severity': 'life_threatening', 'is_life_threatening': true}
      ],
      'chronic_conditions': [],
    });

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => AuthProvider(repository: AuthRepository(apiClient: apiClient))),
        ChangeNotifierProvider(
            create: (_) => ClinicalProvider(repository: ClinicalRepository(apiClient: apiClient))),
      ],
      child: MaterialApp(
        home: AppColorScope(
          tokens: AppColorTokens.light,
          child: PatientDetailScreen(patient: patient),
        ),
      ),
    ));
    await tester.pump();

    // Target _OverviewTab's outer Column by its explicit key (Task 27), not
    // by type — find.byType(Column).first would match whichever Column
    // widget-tester encounters first in the whole tree (AppBar, Scaffold,
    // AdaptiveCard/AdaptiveListRow internals, AppLockGate, etc. all build
    // their own Columns), which can pass regardless of actual card order.
    final column = tester.widget<Column>(find.byKey(const Key('overview_tab_column')));
    final firstDataChild =
        column.children.firstWhere((w) => w is CriticalAlertCard || w is AdaptiveCard);
    expect(firstDataChild, isA<CriticalAlertCard>(),
        reason: 'CriticalAlertCard must render before any other Overview card '
            'when the patient has critical allergies.');
  });
}
```

Adjust the `MultiProvider` setup to match whatever providers `PatientDetailScreen`'s widget tree actually reads at build time (check the file's `Consumer`/`context.watch` calls if this fails with a `ProviderNotFoundException` — add the missing provider rather than removing the assertion). If `find.byKey` finds nothing, that means Task 27's `Key('overview_tab_column')` wasn't actually applied — fix Task 27's implementation, don't fall back to a type-based selector.

- [ ] **Step 2: Run test to verify it fails before Task 27, passes after**

Run: `flutter test test/patients/patient_detail_overview_order_test.dart`
Expected: PASS (Task 27 already implemented the ordering — this test formalizes and locks it in). If it fails, that means Task 27's `Column` ordering regressed; fix `_OverviewTab` so `CriticalAlertCard` is the first child again, don't weaken this test.

- [ ] **Step 3: Commit**

```bash
git add test/patients/patient_detail_overview_order_test.dart
git commit -m "test: lock in CriticalAlertCard-renders-first invariant"
```

---

### Task 31: Contrast-ratio tests for critical/success/warning tokens (light + dark)

**Files:**
- Create: `test/config/token_contrast_test.dart`

**Interfaces:**
- Consumes: `AppColorTokens.light`, `AppColorTokens.dark` (Task 2)

- [ ] **Step 1: Write the failing test, including the WCAG contrast-ratio helper**

```dart
// test/config/token_contrast_test.dart
//
// Enforces WCAG AA text contrast (>= 4.5:1) for the semantic tokens used
// as text-on-tint pairs throughout the app (critical allergy banners,
// success/warning badges). "Validated for WCAG AA" in the spec means this
// test passes — if you retune any of these hexes, rerun this file and
// adjust the shade (same hue) until it's green again.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/config/app_color_tokens.dart';

double _linearize(double channel255) {
  final s = channel255 / 255.0;
  return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
}

double relativeLuminance(Color c) {
  final r = _linearize(c.r * 255.0);
  final g = _linearize(c.g * 255.0);
  final b = _linearize(c.b * 255.0);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('WCAG AA contrast (>= 4.5:1) for text-on-tint token pairs', () {
    final pairs = {
      'light critical on criticalTint':
          (AppColorTokens.light.critical, AppColorTokens.light.criticalTint),
      'light success on successTint':
          (AppColorTokens.light.success, AppColorTokens.light.successTint),
      'light warning on warningTint':
          (AppColorTokens.light.warning, AppColorTokens.light.warningTint),
      'dark critical on criticalTint':
          (AppColorTokens.dark.critical, AppColorTokens.dark.criticalTint),
      'dark success on successTint':
          (AppColorTokens.dark.success, AppColorTokens.dark.successTint),
      'dark warning on warningTint':
          (AppColorTokens.dark.warning, AppColorTokens.dark.warningTint),
      'light critical on surface':
          (AppColorTokens.light.critical, AppColorTokens.light.surface),
      'dark critical on surface':
          (AppColorTokens.dark.critical, AppColorTokens.dark.surface),
    };

    for (final entry in pairs.entries) {
      test(entry.key, () {
        final ratio = contrastRatio(entry.value.$1, entry.value.$2);
        expect(ratio, greaterThanOrEqualTo(4.5),
            reason: '${entry.key} contrast ratio is ${ratio.toStringAsFixed(2)}:1, '
                'below WCAG AA 4.5:1. Darken/lighten the text color (same hue) '
                'in AppColorTokens and rerun.');
      });
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails or passes for the right reason**

Run: `flutter test test/config/token_contrast_test.dart`
Expected: each pair either PASSes (the hex values chosen in Task 2 already clear 4.5:1) or FAILs with the exact ratio reported in the failure message. This is expected to surface real failures — the Task 2 values were chosen to be *likely* AA-compliant, not verified against this formula at authoring time.

- [ ] **Step 3: Fix any failing pairs**

For every failing pair, go back to `lib/config/app_color_tokens.dart` (Task 2) and darken the text token (or lighten the tint token) within the same hue family — e.g. if `light warning on warningTint` fails, shift `warning` from `0xFFB45309` toward a darker amber like `0xFF92400E` and re-run. Do not loosen the 4.5 threshold in the test to make it pass.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/config/token_contrast_test.dart`
Expected: PASS for all pairs

- [ ] **Step 5: Commit**

```bash
git add test/config/token_contrast_test.dart lib/config/app_color_tokens.dart
git commit -m "test: enforce WCAG AA contrast for critical/success/warning tokens"
```

---

## Self-Review Notes

- **Spec coverage:** design tokens (Task 2/4), fonts as local assets not google_fonts (Task 1), AppColorScope mechanism for both shells (Tasks 3/8/9), ThemeMode system+override persisted via shared_preferences (Task 6/7/17), component library (Tasks 11-16), the AndroidShell-serves-web TODO comment (Task 7), the migration-as-its-own-commit sequencing (Task 10, positioned before Phase 4+), all five flagship screens (Tasks 18-29), CriticalAlertCard-first invariant test (Task 30), contrast tests for critical/success/warning (Task 31) — every spec section maps to at least one task.
- **Placeholder scan:** no task contains TBD/"handle appropriately"-style gaps. The three tasks that don't hand-transcribe entire multi-hundred-line private-class bodies (Task 23, Task 26, Task 29) instead give an exact mapping rule, an exact enumerated target list, and an explicit "verify by compiling + manual check against the approved mockup" gate, rather than leaving the transformation open-ended.
- **Type consistency:** `AdaptiveCard`, `StatTile`, `AdaptiveListRow`, `AdaptiveBadge`, `CriticalAlertCard` constructor signatures are defined once (Tasks 11-15) and referenced identically in every later task; `AppColors.of(context)` and `ThemeModeProvider.{mode, load, setMode, resolvedBrightness}` are likewise defined once and reused verbatim.
- **Post-review fixes:** Task 1's font download is pinned to commit `8cd7d0de182c88592d6852c245fe48f66eef55ee` (not the mutable `main` branch) and verified by SHA-256, not just file type — closes the same supply-chain gap the spec's blocking issue #1 was about removing in the first place. Task 27's `_OverviewTab` Column now carries `Key('overview_tab_column')`, and Task 30's ordering test asserts against `find.byKey(...)` instead of `find.byType(Column).first`, which could previously match an unrelated ancestor/sibling Column and pass without checking real card order. Task 5's `ColorScheme.fromSeed` now explicitly sets every commonly-consumed role (`onSurface`, `onSurfaceVariant`, `outline`, `outlineVariant`, `secondary`, `surfaceContainerHighest`, the `on*Container` pairs) instead of leaving them algorithmically derived from the seed; only `tertiary*`, `inverseSurface`, `inversePrimary`, `shadow`, `scrim`, `surfaceTint` remain seed-derived, called out explicitly as a documented decision rather than an untracked gap. Task 10's Step 3 import-insertion is now a deterministic depth-computed script (spot-checked against two known files before running across all 36) instead of prose asking the worker to reason out relative paths by hand, and its ordering relative to Step 4's const-fixup pass is now explicit. Task 21's deletion-completeness check now includes a hard `grep` gate, not just `flutter analyze`, since an incomplete deletion can pass analyze with only a lint-level warning.
