# Platform-Adaptive UI Design Spec

**Goal:** Make the Flutter app feel fully native on both platforms — Material widgets on Android (unchanged), Cupertino widgets on iOS with bottom tab navigation, frosted-white chrome, and iOS-native components throughout.

**Scope:** iOS UI layer only. All data models, repositories, providers, and business logic are untouched.

---

## Decisions

| Question | Decision |
|---|---|
| iOS navigation model | Bottom tab bar (not drawer) |
| Tab structure | 4 tabs + iOS Settings-style More screen |
| Nav bar style | Frosted white, large collapsing title, brand blue as accent only |
| Component depth | Full swap — every widget category gets a Cupertino equivalent |

---

## Architecture

### Platform detection

`lib/core/platform.dart` — single source of truth for all platform branching:

```dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// True when running on a physical or simulated iOS device.
/// Always false on web (Platform.isIOS throws on web).
bool get kIsIOS => !kIsWeb && Platform.isIOS;
```

Also exports two adaptive helpers (implementations detailed in Component Map):
- `showAdaptiveDialog(context, {...})` — `AlertDialog` on Android, `CupertinoAlertDialog` on iOS
- `showAdaptiveActionSheet(context, {...})` — `showModalBottomSheet` on Android, `CupertinoActionSheet` on iOS for destructive confirmations

No other file may import `dart:io Platform` directly. All `Platform.isIOS` checks go through `kIsIOS`.

### App entry point

`main.dart` / `App` widget switches at the root:

```dart
kIsIOS ? const IOSShell() : const AndroidShell()
```

- `IOSShell` wraps `CupertinoApp` → `CupertinoTabScaffold`
- `AndroidShell` wraps `MaterialApp` → existing `Scaffold` + `Drawer`

Both shells share the same `MultiProvider` tree — no provider changes needed.

### Shared colours and text styles

`lib/config/app_colors.dart` replaces the colour constants currently on `AppTheme`. Both shells import from here.

```dart
class AppColors {
  static const primary   = Color(0xFF2563EB); // brand blue → iOS accent
  static const secondary = Color(0xFF7C3AED);
  static const error     = Color(0xFFDC2626);
  static const success   = Color(0xFF16A34A);
  static const warning   = Color(0xFFF59E0B);
  static const gray50    = Color(0xFFF9FAFB);
  static const gray100   = Color(0xFFF3F4F6);
  static const gray600   = Color(0xFF4B5563);
  static const gray900   = Color(0xFF111827);
}
```

`AppTheme` is kept for Android (`ThemeData`) but its colour constants are replaced with calls to `AppColors`.

---

## iOS Navigation Structure

### Shell: `lib/presentation/shell/ios_shell.dart`

`CupertinoTabScaffold` with a `CupertinoTabBar`. Tab bar uses `CupertinoIcons` throughout.

```
Tab 0 — Patients     CupertinoIcons.person_crop_circle
Tab 1 — Roster       CupertinoIcons.list_bullet_clipboard
Tab 2 — Access       CupertinoIcons.lock_shield
Tab 3 — More         CupertinoIcons.ellipsis_circle
```

Each tab body is wrapped in its own `CupertinoTabView` (gives each tab an independent navigation stack — standard iOS pattern). Switching tabs does not pop the navigation stack of the previous tab.

Active tab colour: `AppColors.primary` (#2563EB).

### More screen: `lib/presentation/more/more_screen.dart`

`CupertinoPageScaffold` with a large-title navigation bar ("More") and a scrollable body of `CupertinoListSection.insetGrouped` sections:

**Section 1 — Clinical**
- Dashboard (chart.bar.xaxis icon)
- Emergency Access (cross.circle icon, destructive red tint)

**Section 2 — Admin**
- Staff Profile (person.crop.square icon)
- Reporting & Compliance (doc.text.magnifyingglass icon)
- Subscription & Billing (creditcard icon)

Each row is a `CupertinoListTile` with a `CupertinoIcons` leading icon, title, and trailing chevron. Tapping navigates via `Navigator.push` with `CupertinoPageRoute`.

### Android shell: `lib/presentation/shell/android_shell.dart`

Existing `Scaffold` + `Drawer` extracted from `main.dart` into its own file. Zero behaviour change.

### Navigation within tabs

- All `MaterialPageRoute` calls on iOS-reachable screens are replaced with `CupertinoPageRoute` when `kIsIOS` is true.
- Back button label on iOS: screen title of the previous route (Flutter's default Cupertino behaviour).
- No named routes are added or removed.

---

## Navigation Bar

Every screen that currently uses `AppBar` gains an iOS variant using `CupertinoNavigationBar` (compact) or a `SliverAppBar` + `CupertinoSliverNavigationBar` (large title, collapses on scroll).

**Large-title screens** (top of each tab stack — list screens):
- PatientListScreen, RosterScreen, AccessGrantsScreen, MoreScreen
- Uses `CupertinoSliverNavigationBar` inside a `CustomScrollView`
- Background: iOS system background (white / #F2F2F7 in grouped contexts)
- Title colour: black (`CupertinoColors.label`)
- Trailing actions (if any): plain `CupertinoButton` with icon, no elevation

**Standard-title screens** (pushed detail screens):
- All other screens (PatientDetailScreen, etc.)
- Uses `CupertinoNavigationBar` (compact, non-collapsing)
- Same colour rules

---

## Component Map

### Buttons

| Current | iOS replacement | Notes |
|---|---|---|
| `ElevatedButton` | `CupertinoButton.filled` | Rounded corners (8px), full-width in forms |
| `TextButton` | `CupertinoButton` (no fill) | Blue text, no border |
| `OutlinedButton` | `CupertinoButton` with border decoration | Rare in this app |
| `FloatingActionButton` | `CupertinoButton.filled` in nav bar trailing | FAB pattern does not exist in iOS HIG |
| `IconButton` | `CupertinoButton` wrapping `Icon` | Padding: EdgeInsets.zero |

Button text on iOS: sentence case ("Save diagnosis"), not ALL CAPS.

### Text inputs

| Current | iOS replacement |
|---|---|
| `TextFormField` (outlined border) | `CupertinoTextField` inside a white `Container` with `border: null` |
| Form sections | `CupertinoFormSection.insetGrouped` wrapping `CupertinoTextFormFieldRow` |
| `DropdownButtonFormField` | Tapping opens `CupertinoActionSheet` with options as action buttons |

iOS inputs sit inside grouped card sections (white background on `#F2F2F7` page background). No visible border on individual fields — section grouping provides visual separation.

### Dialogs and confirmations

`showAdaptiveDialog` implementation:

```dart
Future<T?> showAdaptiveDialog<T>({
  required BuildContext context,
  required String title,
  required String content,
  required List<AdaptiveDialogAction> actions,
}) {
  if (kIsIOS) {
    return showCupertinoDialog<T>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(content),
        actions: actions.map((a) => CupertinoDialogAction(
          isDestructiveAction: a.isDestructive,
          onPressed: a.onPressed,
          child: Text(a.label),
        )).toList(),
      ),
    );
  }
  return showDialog<T>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: actions.map((a) => TextButton(
        onPressed: a.onPressed,
        child: Text(a.label,
          style: TextStyle(color: a.isDestructive ? AppColors.error : null)),
      )).toList(),
    ),
  );
}
```

`showAdaptiveActionSheet` is used specifically for destructive confirmations (delete record, revoke grant, etc.). On iOS this renders as a `CupertinoActionSheet` anchored at the bottom with a separate "Cancel" button — the standard iOS destructive-action pattern.

### Lists

| Current | iOS replacement |
|---|---|
| `ListView` + `ListTile` | `CupertinoListSection.insetGrouped` + `CupertinoListTile` |
| Inline delete icon button | `Dismissible` widget with red trailing ("Delete") revealed on left-swipe |
| `Card` wrapping list items | Removed on iOS — inset grouped section provides the card visual |
| `RefreshIndicator` | `CustomScrollView` + `CupertinoSliverRefreshControl` |

Swipe-to-delete applies to all deletable lists: diagnoses, problems, procedures, immunizations, vital signs, documents, prescriptions (discontinue), access grants (revoke).

Swipe threshold: 40% of item width to confirm. Revealed action label: "Delete" (red) or "Revoke" where appropriate.

### Snackbars / toasts

`SnackBar` has no Cupertino equivalent. On iOS, replace with a top-anchored banner:

- Appears below the navigation bar
- White background, 1pt border radius, subtle shadow
- Auto-dismisses after 2 seconds
- Success: green left border stripe; error: red; neutral: none

Implementation: `OverlayEntry` positioned at top of screen. A single `AdaptiveToast.show(context, message, type)` call is used everywhere `ScaffoldMessenger.of(context).showSnackBar(...)` currently appears.

### Other components

| Current | iOS replacement |
|---|---|
| `Switch` | `CupertinoSwitch` |
| `CircularProgressIndicator` | `CupertinoActivityIndicator` |
| `LinearProgressIndicator` | `CupertinoActivityIndicator.partiallyRevealed` (or custom) |
| `Checkbox` | `CupertinoCheckbox` (Flutter 3.14+) |
| `Slider` | `CupertinoSlider` |
| `SearchBar` (Material 3) | `CupertinoSearchTextField` |
| `BottomSheet` (modal forms) | Simple forms: `showCupertinoModalPopup` with tall `CupertinoActionSheet`. Complex multi-field forms: `CupertinoPageRoute` full-screen push. |
| `ExpansionTile` (ClinicalRecordTab) | `CupertinoListSection` with collapsible section header |
| `TabBar` + `TabBarView` (PatientDetailScreen) | `CupertinoSegmentedControl` or `CupertinoSlidingSegmentedControl` for tab switching within a screen |

---

## PatientDetailScreen on iOS

The current 5–6-tab `TabBar` inside a `Scaffold` becomes:

- `CupertinoPageScaffold` with compact nav bar
- `CupertinoSlidingSegmentedControl` below the nav bar for tab selection (Overview / Appts / Rx / Labs / Docs / Clinical)
- Tab content swaps via `IndexedStack` (keeps state per tab, no re-fetch on switch)
- FAB → trailing nav bar `CupertinoButton` with "+" icon, which opens the existing picker logic

---

## Files to Create

| File | Responsibility |
|---|---|
| `lib/core/platform.dart` | `kIsIOS`, `showAdaptiveDialog`, `showAdaptiveActionSheet`, `AdaptiveToast` |
| `lib/config/app_colors.dart` | Shared colour constants (both platforms) |
| `lib/presentation/shell/ios_shell.dart` | `CupertinoApp` + `CupertinoTabScaffold` root |
| `lib/presentation/shell/android_shell.dart` | Extracted `MaterialApp` + `Drawer` root |
| `lib/presentation/more/more_screen.dart` | iOS Settings-style More screen |

## Files to Modify

Every screen that has `AppBar`, `Scaffold`, `ElevatedButton`, `TextFormField`, `AlertDialog`, `SnackBar`, `ListTile`, or `RefreshIndicator` — which is most screens. The modification pattern is always the same:

```dart
// Before
AppBar(title: Text('Patients'))

// After
kIsIOS
  ? CupertinoNavigationBar(middle: Text('Patients'))
  : AppBar(title: Text('Patients'))
```

Screens with lists also gain `Dismissible` swipe-to-delete wrappers around deletable items.

---

## What Does Not Change

- `lib/data/` — all models, repositories, providers: untouched
- `lib/core/api/` — API client and error handling: untouched  
- `lib/config/theme.dart` — kept for Android `ThemeData`; colour constants migrated to `AppColors`
- Route names and navigation logic within screens
- The Android user experience — every Android path is a zero-regression zone

---

## Testing Approach

- `flutter analyze` must pass with no new issues after each task
- Manual testing on iOS Simulator (iPhone 15) and Android Emulator (Pixel 7) after each task
- No automated widget tests are added in this pass — the existing test suite (Laravel backend) is unaffected

---

## Out of Scope

- Dark mode support (separate task)
- iPad / tablet layout
- macOS or web adaptive changes
- Push notifications
- Offline sync UI
