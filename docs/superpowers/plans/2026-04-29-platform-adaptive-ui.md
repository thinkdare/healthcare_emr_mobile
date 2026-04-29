# Platform-Adaptive UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Flutter app feel fully native on iOS (Cupertino widgets, bottom tab bar, frosted chrome) while keeping Android exactly as-is (Material, drawer navigation).

**Architecture:** A `platform.dart` utility exposes `kIsIOS` and adaptive helpers. `main.dart` switches between `IOSShell` (CupertinoApp + CupertinoTabScaffold) and `AndroidShell` (existing MaterialApp + Drawer) at the root. All data/repository/provider layers are untouched. Every screen gains conditional rendering via `kIsIOS`.

**Tech Stack:** Flutter 3, `package:flutter/cupertino.dart`, `CupertinoIcons`, existing Provider state management. No new packages needed — Cupertino is built into Flutter.

---

## File Map

| Action | File | Responsibility |
|---|---|---|
| **Create** | `lib/config/app_colors.dart` | Shared colour constants (both platforms) |
| **Create** | `lib/core/platform.dart` | `kIsIOS`, `AdaptiveDialogAction`, `showAdaptiveDialog`, `showAdaptiveActionSheet`, `AdaptiveToast` |
| **Create** | `lib/presentation/shell/android_shell.dart` | Extracted MaterialApp + Drawer root (Android) |
| **Create** | `lib/presentation/shell/ios_shell.dart` | CupertinoApp + CupertinoTabScaffold root (iOS) |
| **Create** | `lib/presentation/more/more_screen.dart` | iOS Settings-style More tab |
| **Modify** | `lib/config/theme.dart` | Replace inline colour literals with `AppColors` |
| **Modify** | `lib/main.dart` | Switch on `kIsIOS` to choose shell |
| **Modify** | All 20 presentation screens | Adaptive nav bars, buttons, dialogs, lists, forms |

---

## Task 1: Shared colour constants — `app_colors.dart`

**Files:**
- Create: `lib/config/app_colors.dart`
- Modify: `lib/config/theme.dart`

- [ ] **Step 1: Create `app_colors.dart`**

```dart
// lib/config/app_colors.dart
import 'package:flutter/cupertino.dart';

class AppColors {
  static const primary   = Color(0xFF2563EB);
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

- [ ] **Step 2: Update `theme.dart` — replace inline colour literals with `AppColors`**

Add the import at the top of `lib/config/theme.dart`:
```dart
import 'app_colors.dart';
```

Then do a global find-and-replace across `theme.dart`:

| Find | Replace |
|---|---|
| `Color(0xFF2563EB)` | `AppColors.primary` |
| `Color(0xFF7C3AED)` | `AppColors.secondary` |
| `Color(0xFFDC2626)` | `AppColors.error` |
| `Color(0xFF16A34A)` | `AppColors.success` |
| `Color(0xFFF59E0B)` | `AppColors.warning` |
| `Color(0xFFF9FAFB)` | `AppColors.gray50` |
| `Color(0xFFF3F4F6)` | `AppColors.gray100` |
| `Color(0xFF4B5563)` | `AppColors.gray600` |
| `Color(0xFF111827)` | `AppColors.gray900` |
| `AppTheme.primaryColor` (in theme.dart only) | `AppColors.primary` |

Remove the old colour constant declarations from `AppTheme` (the 9 `static const Color` lines). Keep `AppTheme.lightTheme` getter — Android still uses it.

- [ ] **Step 3: Update `AppTheme` references in dashboard screen**

In `lib/presentation/dashboard/screens/provider_dashboard_screen.dart`, replace:
```dart
import '../../../config/theme.dart';
// and references like:
AppTheme.primaryColor
AppTheme.secondaryColor
AppTheme.errorColor
AppTheme.successColor
AppTheme.warningColor
AppTheme.gray50
AppTheme.gray100
AppTheme.gray600
AppTheme.gray900
```
with:
```dart
import '../../../config/app_colors.dart';
// and:
AppColors.primary
AppColors.secondary
// etc.
```

Do the same replacement in every file that currently references `AppTheme.primaryColor` (or any `AppTheme` colour constant). Run:
```bash
grep -rn "AppTheme\." lib/ --include="*.dart" | grep -v "AppTheme.lightTheme"
```
Each result needs `AppTheme.xyzColor` replaced with `AppColors.xyz`.

- [ ] **Step 4: Verify**

```bash
cd /home/dh/Forge/sandbox/healthcare_emr_mobile
flutter analyze lib/config/ 2>&1
```
Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add lib/config/app_colors.dart lib/config/theme.dart
git add lib/presentation/  # catches any AppTheme→AppColors replacements
git commit -m "refactor(mobile): extract AppColors shared colour constants from AppTheme"
```

---

## Task 2: Platform utility — `platform.dart`

**Files:**
- Create: `lib/core/platform.dart`

This file is the single gate for all platform branching. Every `kIsIOS` check in the app imports from here.

- [ ] **Step 1: Create `lib/core/platform.dart`**

```dart
// lib/core/platform.dart
//
// Single source of truth for platform detection and adaptive UI helpers.
// Import this wherever you need kIsIOS or adaptive dialogs/toasts.
// Do NOT import dart:io Platform directly in any other file.
import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart'
    show
        AlertDialog,
        BuildContext,
        Colors,
        MaterialPageRoute,
        Navigator,
        OverlayEntry,
        Positioned,
        ScaffoldMessenger,
        SnackBar,
        TextButton,
        showDialog,
        showModalBottomSheet;
import 'package:flutter/widgets.dart';
import '../config/app_colors.dart';

/// True when running on a physical or simulated iOS device.
/// Always false on web (Platform.isIOS throws on web).
bool get kIsIOS => !kIsWeb && Platform.isIOS;

// ── Adaptive dialog ───────────────────────────────────────────────────────────

class AdaptiveDialogAction {
  final String label;
  final VoidCallback? onPressed;
  final bool isDestructive;

  const AdaptiveDialogAction({
    required this.label,
    this.onPressed,
    this.isDestructive = false,
  });
}

/// Shows CupertinoAlertDialog on iOS, AlertDialog on Android.
Future<void> showAdaptiveDialog({
  required BuildContext context,
  required String title,
  required String content,
  required List<AdaptiveDialogAction> actions,
}) {
  if (kIsIOS) {
    return showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(content),
        actions: actions
            .map((a) => CupertinoDialogAction(
                  isDestructiveAction: a.isDestructive,
                  onPressed: a.onPressed ?? () => Navigator.of(context).pop(),
                  child: Text(a.label),
                ))
            .toList(),
      ),
    );
  }
  return showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: actions
          .map((a) => TextButton(
                onPressed: a.onPressed ?? () => Navigator.of(context).pop(),
                child: Text(
                  a.label,
                  style: TextStyle(
                      color: a.isDestructive ? AppColors.error : null),
                ),
              ))
          .toList(),
    ),
  );
}

// ── Adaptive action sheet (destructive confirmations) ─────────────────────────

/// Shows a CupertinoActionSheet on iOS, a bottom sheet on Android.
/// [destructiveLabel] is shown in red. Calls [onConfirm] when tapped.
Future<void> showAdaptiveActionSheet({
  required BuildContext context,
  required String title,
  required String message,
  required String destructiveLabel,
  required VoidCallback onConfirm,
  String cancelLabel = 'Cancel',
}) {
  if (kIsIOS) {
    return showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: Text(title),
        message: Text(message),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            child: Text(destructiveLabel),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(cancelLabel),
        ),
      ),
    );
  }
  return showModalBottomSheet(
    context: context,
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(message),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: Text(destructiveLabel,
                style: const TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.of(context).pop();
              onConfirm();
            },
          ),
          ListTile(
            title: Text(cancelLabel),
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    ),
  );
}

// ── Adaptive toast ────────────────────────────────────────────────────────────

enum ToastType { success, error, info }

/// Shows a SnackBar on Android, a top-anchored banner on iOS.
/// On iOS the banner auto-dismisses after 2 seconds.
void showAdaptiveToast(
  BuildContext context,
  String message, {
  ToastType type = ToastType.info,
}) {
  if (!kIsIOS) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    return;
  }

  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  final borderColor = switch (type) {
    ToastType.success => AppColors.success,
    ToastType.error   => AppColors.error,
    ToastType.info    => AppColors.primary,
  };

  entry = OverlayEntry(
    builder: (_) => Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground.resolveFrom(context),
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: borderColor, width: 4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Text(message,
              style: const TextStyle(fontSize: 14, color: CupertinoColors.label)),
        ),
      ),
    ),
  );

  overlay.insert(entry);
  Future.delayed(const Duration(seconds: 2), entry.remove);
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/core/platform.dart 2>&1
```
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/core/platform.dart
git commit -m "feat(mobile): add platform.dart — kIsIOS, showAdaptiveDialog, showAdaptiveActionSheet, showAdaptiveToast"
```

---

## Task 3: App shell split — Android shell, iOS shell, More screen, main.dart

**Files:**
- Create: `lib/presentation/shell/android_shell.dart`
- Create: `lib/presentation/more/more_screen.dart`
- Create: `lib/presentation/shell/ios_shell.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: Create `lib/presentation/shell/android_shell.dart`**

Extract the `MultiProvider` + `MaterialApp` block from `main.dart` into this file. This is the existing Android experience, unchanged.

```dart
// lib/presentation/shell/android_shell.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../data/providers/auth_provider.dart';
import '../../presentation/auth/screens/login_screen.dart';
import '../../presentation/dashboard/screens/provider_dashboard_screen.dart';

/// Android root — MaterialApp + existing drawer navigation.
/// Wraps the authenticated home in ProviderDashboardScreen which contains
/// the drawer, stats, and all navigation.
class AndroidShell extends StatelessWidget {
  const AndroidShell({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Healthcare EMR',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const _AuthWrapper(),
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

- [ ] **Step 2: Create `lib/presentation/more/more_screen.dart`**

```dart
// lib/presentation/more/more_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../data/providers/auth_provider.dart';
import '../auth/screens/login_screen.dart';
import '../dashboard/screens/provider_dashboard_screen.dart';
import '../emergency_access/screens/emergency_access_screen.dart';
import '../profile/screens/staff_profile_screen.dart';
import '../reporting/screens/reporting_screen.dart';
import '../subscription/screens/subscription_details_screen.dart';

/// iOS More tab — Settings-style list of secondary destinations.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final showEmergency = auth.canEmergencyAccess;

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        largeTitle: Text('More'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoListSection.insetGrouped(
              header: const Text('Clinical'),
              children: [
                CupertinoListTile(
                  leading: const Icon(CupertinoIcons.chart_bar_alt_fill,
                      color: AppColors.primary),
                  title: const Text('Dashboard'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => _push(context,
                      const ProviderDashboardScreen()),
                ),
                if (showEmergency)
                  CupertinoListTile(
                    leading: const Icon(CupertinoIcons.exclamationmark_circle,
                        color: AppColors.error),
                    title: const Text('Emergency Access'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => _push(context, const EmergencyAccessScreen()),
                  ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('Account'),
              children: [
                CupertinoListTile(
                  leading: const Icon(CupertinoIcons.person_crop_square,
                      color: AppColors.primary),
                  title: const Text('Staff Profile'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => _push(context, const StaffProfileScreen()),
                ),
                CupertinoListTile(
                  leading: const Icon(
                      CupertinoIcons.doc_text_magnifyingglass,
                      color: AppColors.primary),
                  title: const Text('Reporting & Compliance'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => _push(context, const ReportingScreen()),
                ),
                CupertinoListTile(
                  leading: const Icon(CupertinoIcons.creditcard,
                      color: AppColors.primary),
                  title: const Text('Subscription & Billing'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () =>
                      _push(context, const SubscriptionDetailsScreen()),
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              children: [
                CupertinoListTile(
                  leading: const Icon(CupertinoIcons.square_arrow_left,
                      color: AppColors.error),
                  title: const Text('Sign Out',
                      style: TextStyle(color: AppColors.error)),
                  onTap: () async {
                    await context.read<AuthProvider>().logout();
                    if (context.mounted) {
                      Navigator.of(context, rootNavigator: true)
                          .pushAndRemoveUntil(
                        CupertinoPageRoute(
                            builder: (_) => const LoginScreen()),
                        (_) => false,
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => screen));
  }
}
```

- [ ] **Step 3: Create `lib/presentation/shell/ios_shell.dart`**

```dart
// lib/presentation/shell/ios_shell.dart
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../data/providers/auth_provider.dart';
import '../access_grants/screens/access_grants_screen.dart';
import '../auth/screens/login_screen.dart';
import '../more/more_screen.dart';
import '../patients/screens/patient_list_screen.dart';
import '../roster/screens/roster_screen.dart';

/// iOS root — CupertinoApp + CupertinoTabScaffold.
/// Four tabs: Patients, Roster, Access, More.
class IOSShell extends StatelessWidget {
  const IOSShell({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Healthcare EMR',
      debugShowCheckedModeBanner: false,
      theme: const CupertinoThemeData(
        primaryColor: AppColors.primary,
      ),
      home: const _IOSAuthWrapper(),
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
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        activeColor: AppColors.primary,
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
    );
  }
}
```

- [ ] **Step 4: Update `lib/main.dart`**

Replace the `MultiProvider` child from:
```dart
child: MaterialApp(
  title: AppConfig.appName,
  debugShowCheckedModeBanner: false,
  theme: AppTheme.lightTheme,
  home: const AuthWrapper(),
),
```

to:
```dart
child: kIsIOS ? const IOSShell() : const AndroidShell(),
```

Add these imports to `main.dart`:
```dart
import 'core/platform.dart';
import 'presentation/shell/android_shell.dart';
import 'presentation/shell/ios_shell.dart';
```

Remove the old `AuthWrapper` class from `main.dart` (it's now in `android_shell.dart`). Remove the old `MaterialApp`-related imports that are no longer used in `main.dart` (`theme.dart`, `login_screen.dart`, `provider_dashboard_screen.dart`).

- [ ] **Step 5: Verify**

```bash
flutter analyze lib/main.dart lib/presentation/shell/ lib/presentation/more/ 2>&1
```
Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/shell/ lib/presentation/more/ lib/main.dart
git commit -m "feat(mobile): split app shell — CupertinoTabScaffold on iOS, unchanged drawer on Android"
```

---

## Task 4: Adaptive navigation bars — all screens

**Pattern:** Every screen that has `AppBar` gets a conditional. Large-title screens use `CupertinoSliverNavigationBar` + `CustomScrollView`. Compact screens use `CupertinoNavigationBar` in `CupertinoPageScaffold`.

All screens also replace `MaterialPageRoute` with `CupertinoPageRoute` when `kIsIOS`.

**Files to add import `'../../core/platform.dart'` to:**
Every screen listed below.

### Large-title pattern (list screens)

Apply to: `patient_list_screen.dart`, `roster_screen.dart`, `access_grants_screen.dart`

**Before** (in `patient_list_screen.dart`):
```dart
return Scaffold(
  appBar: AppBar(title: const Text('Patients'), actions: [...]),
  body: ...,
  floatingActionButton: ...,
);
```

**After:**
```dart
if (kIsIOS) {
  return CupertinoPageScaffold(
    child: CustomScrollView(
      slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: const Text('Patients'),
          trailing: // trailing actions as CupertinoButton(s)
        ),
        SliverToBoxAdapter(child: /* body content */),
      ],
    ),
  );
}
// Android unchanged
return Scaffold(
  appBar: AppBar(title: const Text('Patients'), actions: [...]),
  body: ...,
  floatingActionButton: ...,
);
```

### Compact-title pattern (detail/form screens)

Apply to all other screens that have `AppBar`:
`patient_detail_screen.dart`, `patient_form_screen.dart`, `staff_profile_screen.dart`, `reporting_screen.dart`, `subscription_details_screen.dart`, `subscription_upgrade_screen.dart`, `billing_invoices_screen.dart`, `access_grants_screen.dart` (inner), `request_access_screen.dart`, `emergency_access_screen.dart`, `trigger_emergency_access_screen.dart`, `facilities_list_screen.dart`, `facility_form_screen.dart`, `provider_invitation_screen.dart`, `provider_dashboard_screen.dart` (More item screens).

**Before:**
```dart
return Scaffold(
  appBar: AppBar(title: const Text('Staff Profile')),
  body: ...,
);
```

**After:**
```dart
if (kIsIOS) {
  return CupertinoPageScaffold(
    navigationBar: const CupertinoNavigationBar(
      middle: Text('Staff Profile'),
    ),
    child: SafeArea(child: /* body content */),
  );
}
return Scaffold(
  appBar: AppBar(title: const Text('Staff Profile')),
  body: ...,
);
```

### CupertinoPageRoute pattern

Every `Navigator.push(context, MaterialPageRoute(builder: (_) => Screen()))` becomes:
```dart
Navigator.push(
  context,
  kIsIOS
      ? CupertinoPageRoute(builder: (_) => Screen())
      : MaterialPageRoute(builder: (_) => Screen()),
);
```

Apply throughout: `provider_dashboard_screen.dart` (drawer taps), `patient_list_screen.dart`, `patient_detail_screen.dart`, `clinical_record_tab.dart`, `roster_screen.dart`, `access_grants_screen.dart`, `emergency_access_screen.dart`.

- [ ] **Step 1: Add `kIsIOS` import to all affected screens**

For each file in the lists above, add at the top:
```dart
import '../../../core/platform.dart'; // adjust relative path per file
```

- [ ] **Step 2: Apply large-title pattern to 3 list screens**

`patient_list_screen.dart`, `roster_screen.dart`, `access_grants_screen.dart` — wrap body in `CustomScrollView` with `CupertinoSliverNavigationBar` on iOS.

- [ ] **Step 3: Apply compact-title pattern to all remaining screens with AppBar**

Follow the compact-title pattern above for each file.

- [ ] **Step 4: Replace MaterialPageRoute throughout**

Replace every `MaterialPageRoute` with the `kIsIOS` conditional pattern above.

- [ ] **Step 5: Verify**

```bash
flutter analyze lib/presentation/ 2>&1 | grep -v "^info"
```
Expected: no errors or warnings.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/
git commit -m "feat(mobile): adaptive navigation bars and CupertinoPageRoute on iOS"
```

---

## Task 5: Adaptive buttons — all screens

**Pattern:** Replace `ElevatedButton` with `CupertinoButton.filled` on iOS. Replace `TextButton` with `CupertinoButton` on iOS. Button text is sentence case on iOS (not ALL CAPS). `FloatingActionButton` on iOS becomes a `CupertinoButton` trailing item in the navigation bar or is dropped where the nav bar action covers it.

**Applies to every file that uses `ElevatedButton` or `TextButton`.**

Run to find them all:
```bash
grep -rln "ElevatedButton\|TextButton\|OutlinedButton" lib/presentation/ --include="*.dart"
```

**ElevatedButton pattern:**
```dart
// Before
ElevatedButton(
  onPressed: _save,
  child: const Text('SAVE'),
)

// After
kIsIOS
  ? CupertinoButton.filled(
      onPressed: _save,
      child: const Text('Save'),  // sentence case on iOS
    )
  : ElevatedButton(
      onPressed: _save,
      child: const Text('SAVE'),
    )
```

**TextButton / cancel pattern:**
```dart
// Before
TextButton(onPressed: _cancel, child: const Text('Cancel'))

// After
kIsIOS
  ? CupertinoButton(
      onPressed: _cancel,
      child: const Text('Cancel'),
    )
  : TextButton(onPressed: _cancel, child: const Text('Cancel'))
```

**Full-width button pattern** (used in forms — `SizedBox(width: double.infinity, child: ElevatedButton(...))`):
```dart
kIsIOS
  ? SizedBox(
      width: double.infinity,
      child: CupertinoButton.filled(
        onPressed: _save,
        child: const Text('Save Diagnosis'),
      ),
    )
  : SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _save,
        child: const Text('SAVE DIAGNOSIS'),
      ),
    )
```

**Files to update:** `login_screen.dart`, `facility_picker_screen.dart`, `patient_form_screen.dart`, `clinical_forms.dart`, `clinical_record_forms.dart`, `request_access_screen.dart`, `trigger_emergency_access_screen.dart`, `facility_form_screen.dart`, `staff_profile_screen.dart`, `subscription_upgrade_screen.dart`, `provider_invitation_screen.dart`, `provider_dashboard_screen.dart`.

- [ ] **Step 1: Apply ElevatedButton → CupertinoButton.filled in all form screens**

- [ ] **Step 2: Apply TextButton → CupertinoButton in all screens**

- [ ] **Step 3: Verify**

```bash
flutter analyze lib/presentation/ 2>&1 | grep -v "^info"
```
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/
git commit -m "feat(mobile): CupertinoButton on iOS — primary and text button variants"
```

---

## Task 6: Adaptive dialogs and toasts

**Replaces:** `showDialog` + `AlertDialog` → `showAdaptiveDialog`. `ScaffoldMessenger.showSnackBar` → `showAdaptiveToast`. Destructive confirmations (delete, revoke, logout) → `showAdaptiveActionSheet`.

**Files:** every file found by:
```bash
grep -rln "showDialog\|AlertDialog\|showSnackBar\|SnackBar" lib/presentation/ --include="*.dart"
```

### showDialog → showAdaptiveDialog

**Before** (logout confirm in `provider_dashboard_screen.dart`):
```dart
final confirmed = await showDialog<bool>(
  context: context,
  builder: (ctx) => AlertDialog(
    title: const Text('Sign Out'),
    content: const Text('Are you sure you want to sign out?'),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(ctx).pop(false),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () => Navigator.of(ctx).pop(true),
        child: const Text('Sign Out',
            style: TextStyle(color: Colors.red)),
      ),
    ],
  ),
);
```

**After:**
```dart
bool confirmed = false;
await showAdaptiveDialog(
  context: context,
  title: 'Sign Out',
  content: 'Are you sure you want to sign out?',
  actions: [
    AdaptiveDialogAction(
      label: 'Cancel',
      onPressed: () => Navigator.of(context).pop(),
    ),
    AdaptiveDialogAction(
      label: 'Sign Out',
      isDestructive: true,
      onPressed: () {
        confirmed = true;
        Navigator.of(context).pop();
      },
    ),
  ],
);
if (confirmed) { /* proceed */ }
```

### Delete confirmations → showAdaptiveActionSheet

**Before** (in `clinical_record_tab.dart` `_confirmDelete`):
```dart
return showDialog(
  context: context,
  builder: (ctx) => AlertDialog(
    title: const Text('Delete Record'),
    content: Text('Delete this $label? This cannot be undone.'),
    actions: [
      TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel')),
      TextButton(
        onPressed: () { Navigator.pop(ctx); onConfirm(); },
        child: const Text('Delete',
            style: TextStyle(color: Colors.red)),
      ),
    ],
  ),
);
```

**After:**
```dart
return showAdaptiveActionSheet(
  context: context,
  title: 'Delete Record',
  message: 'Delete this $label? This cannot be undone.',
  destructiveLabel: 'Delete',
  onConfirm: onConfirm,
);
```

### SnackBar → showAdaptiveToast

**Before:**
```dart
ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(content: Text('Patient registered')),
);
```

**After:**
```dart
showAdaptiveToast(context, 'Patient registered');
```

For success/error variants:
```dart
showAdaptiveToast(context, 'Saved successfully', type: ToastType.success);
showAdaptiveToast(context, 'Failed to save', type: ToastType.error);
```

Apply to all 86 `SnackBar` usages across the presentation layer.

- [ ] **Step 1: Add `platform.dart` import to all affected files (if not already added in Task 4)**

- [ ] **Step 2: Replace all `showDialog`/`AlertDialog` with `showAdaptiveDialog`**

- [ ] **Step 3: Replace all destructive `showDialog` calls with `showAdaptiveActionSheet`**

Destructive ones to find: delete patient, delete document, delete roster entry, revoke access grant, logout, cancel appointment, discontinue prescription.

- [ ] **Step 4: Replace all `ScaffoldMessenger.of(context).showSnackBar` with `showAdaptiveToast`**

- [ ] **Step 5: Verify**

```bash
flutter analyze lib/presentation/ 2>&1 | grep -v "^info"
```
Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/
git commit -m "feat(mobile): adaptive dialogs, action sheets, and toast on iOS"
```

---

## Task 7: Adaptive forms and inputs

**Replaces:** `TextFormField` → `CupertinoTextField` inside `CupertinoFormSection.insetGrouped`. `DropdownButtonFormField` → tap opens `CupertinoActionSheet` picker.

**Files with forms:** `login_screen.dart`, `patient_form_screen.dart`, `clinical_forms.dart`, `clinical_record_forms.dart`, `request_access_screen.dart`, `trigger_emergency_access_screen.dart`, `facility_form_screen.dart`, `staff_profile_screen.dart`.

### TextFormField → CupertinoTextField pattern

**Before** (in `clinical_record_forms.dart`):
```dart
TextFormField(
  controller: _descCtrl,
  decoration: _field('Description *'),
  validator: (v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null,
),
```

**After:**
```dart
kIsIOS
  ? CupertinoTextField(
      controller: _descCtrl,
      placeholder: 'Description *',
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    )
  : TextFormField(
      controller: _descCtrl,
      decoration: _field('Description *'),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Required' : null,
    ),
```

For iOS, wrap groups of related inputs in `CupertinoListSection.insetGrouped` for the card-group visual. Validation on iOS: check fields manually in `_save()` and call `showAdaptiveToast(context, 'Description is required', type: ToastType.error)` rather than relying on Form + validator.

### DropdownButtonFormField → CupertinoActionSheet picker pattern

**Before** (in `clinical_record_forms.dart` DiagnosisForm):
```dart
DropdownButtonFormField<String>(
  initialValue: _type,
  decoration: _field('Diagnosis Type'),
  items: _types
      .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)))
      .toList(),
  onChanged: (v) => setState(() => _type = v!),
),
```

**After:**
```dart
kIsIOS
  ? GestureDetector(
      onTap: () => _showTypePicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_types.firstWhere((t) => t.$1 == _type).$2),
            const Icon(CupertinoIcons.chevron_down, size: 14,
                color: CupertinoColors.systemGrey),
          ],
        ),
      ),
    )
  : DropdownButtonFormField<String>(
      initialValue: _type,
      decoration: _field('Diagnosis Type'),
      items: _types
          .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)))
          .toList(),
      onChanged: (v) => setState(() => _type = v!),
    ),
```

Add the picker method to the state class:
```dart
void _showTypePicker(BuildContext context) {
  showCupertinoModalPopup(
    context: context,
    builder: (_) => CupertinoActionSheet(
      title: const Text('Diagnosis Type'),
      actions: _types
          .map((t) => CupertinoActionSheetAction(
                onPressed: () {
                  setState(() => _type = t.$1);
                  Navigator.of(context).pop();
                },
                child: Text(t.$2),
              ))
          .toList(),
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
    ),
  );
}
```

Apply the same `_showXxxPicker` pattern to every dropdown in every form.

### Toggle / checkbox fields

`Switch` → `CupertinoSwitch`:
```dart
kIsIOS
  ? CupertinoSwitch(value: _isConfidential,
      onChanged: (v) => setState(() => _isConfidential = v))
  : Switch(value: _isConfidential,
      onChanged: (v) => setState(() => _isConfidential = v))
```

- [ ] **Step 1: Apply TextFormField → CupertinoTextField to all form files**

- [ ] **Step 2: Apply DropdownButtonFormField → CupertinoActionSheet picker to all form files**

- [ ] **Step 3: Apply Switch → CupertinoSwitch to all toggle fields**

- [ ] **Step 4: Verify**

```bash
flutter analyze lib/presentation/ 2>&1 | grep -v "^info"
```
Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/
git commit -m "feat(mobile): CupertinoTextField, pickers, and CupertinoSwitch on iOS forms"
```

---

## Task 8: Adaptive lists — CupertinoListSection, swipe-to-delete, pull-to-refresh

**Applies to:** screens that currently use `ListView` + `ListTile` for browsable data, and `RefreshIndicator` for pull-to-refresh.

**Files:** `patient_list_screen.dart`, `access_grants_screen.dart`, `emergency_access_screen.dart`, `facilities_list_screen.dart`, `billing_invoices_screen.dart`, `reporting_screen.dart`, `clinical_record_tab.dart`.

### ListTile → CupertinoListTile pattern

**Before:**
```dart
ListTile(
  title: Text(p.fullName,
      style: const TextStyle(fontWeight: FontWeight.w600)),
  subtitle: Text('${p.mrn} · ${p.ageDisplay}'),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => _openPatient(p),
)
```

**After:**
```dart
kIsIOS
  ? CupertinoListTile(
      title: Text(p.fullName,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${p.mrn} · ${p.ageDisplay}'),
      trailing: const CupertinoListTileChevron(),
      onTap: () => _openPatient(p),
    )
  : ListTile(
      title: Text(p.fullName,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${p.mrn} · ${p.ageDisplay}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openPatient(p),
    )
```

Wrap groups of `CupertinoListTile` in `CupertinoListSection.insetGrouped` on iOS.

### Swipe-to-delete pattern (clinical record tab deletable items)

Wrap each deletable list item in a `Dismissible` on iOS:

```dart
kIsIOS
  ? Dismissible(
      key: ValueKey(v.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        bool confirmed = false;
        await showAdaptiveActionSheet(
          context: context,
          title: 'Delete vital sign reading',
          message: 'This cannot be undone.',
          destructiveLabel: 'Delete',
          onConfirm: () => confirmed = true,
        );
        return confirmed;
      },
      onDismissed: (_) =>
          context.read<ClinicalProvider>().deleteVitalSign(v.id),
      background: Container(
        color: AppColors.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(CupertinoIcons.delete, color: Colors.white),
      ),
      child: _VitalSignTile(v),
    )
  : _VitalSignTile(v), // existing tile with trash icon button
```

Apply to: VitalSigns, Diagnoses, ProblemList, Procedures, Immunizations sections in `clinical_record_tab.dart`. Also to documents list in the documents tab within `patient_detail_screen.dart`.

### RefreshIndicator → CupertinoSliverRefreshControl

For list screens that already use `CustomScrollView` (from Task 4), add `CupertinoSliverRefreshControl` as the first sliver:

```dart
// iOS — inside the CustomScrollView slivers list:
CupertinoSliverRefreshControl(
  onRefresh: () async => clinical.loadAll(patientId),
),

// Android — keep RefreshIndicator wrapper unchanged
```

Apply to: `patient_list_screen.dart`, `access_grants_screen.dart`, `emergency_access_screen.dart`, `clinical_record_tab.dart`.

- [ ] **Step 1: Apply ListTile → CupertinoListTile in all list screens**

- [ ] **Step 2: Add Dismissible swipe-to-delete in `clinical_record_tab.dart`**

- [ ] **Step 3: Add Dismissible swipe-to-delete for documents in `patient_detail_screen.dart`**

- [ ] **Step 4: Replace RefreshIndicator with CupertinoSliverRefreshControl on iOS**

- [ ] **Step 5: Verify**

```bash
flutter analyze lib/presentation/ 2>&1 | grep -v "^info"
```
Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/
git commit -m "feat(mobile): CupertinoListSection, swipe-to-delete, and CupertinoSliverRefreshControl on iOS"
```

---

## Task 9: PatientDetailScreen — segmented control

**File:** `lib/presentation/patients/screens/patient_detail_screen.dart`

The existing `TabBar` + `TabBarView` becomes `CupertinoSlidingSegmentedControl` + `IndexedStack` on iOS. The FAB becomes a `+` button in the navigation bar trailing.

- [ ] **Step 1: Add iOS segmented control state to `_PatientDetailScreenState`**

```dart
// Add to state class:
int _iosSegment = 0;
```

- [ ] **Step 2: Replace the iOS `build` path**

Inside `build()`, add an iOS branch that replaces the entire `Scaffold` return:

```dart
if (kIsIOS) {
  return CupertinoPageScaffold(
    navigationBar: CupertinoNavigationBar(
      middle: Text(_patient.fullName),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _openClinicalForm,
        child: const Icon(CupertinoIcons.add),
      ),
    ),
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            child: CupertinoSlidingSegmentedControl<int>(
              groupValue: _iosSegment,
              onValueChanged: (v) =>
                  setState(() => _iosSegment = v ?? 0),
              children: {
                for (int i = 0;
                    i < _visibleIndices.length;
                    i++)
                  i: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4),
                    child: Text(
                      const [
                        'Overview',
                        'Appts',
                        'Rx',
                        'Labs',
                        'Docs',
                        'Clinical'
                      ][_visibleIndices[i]],
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              },
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _iosSegment,
              children: [
                for (final i in _visibleIndices)
                  _allTabViews[i],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
// existing Scaffold build for Android below
```

Note: Move `allTabViews` list construction to a getter so it is accessible from both iOS and Android paths:

```dart
List<Widget> get _allTabViews => [
  _OverviewTab(patient: _patient),
  _AppointmentsTab(patientId: _patient.id),
  _PrescriptionsTab(patientId: _patient.id),
  _LabResultsTab(patientId: _patient.id),
  _DocumentsTab(patientId: _patient.id),
  const ClinicalRecordTab(),
];
```

- [ ] **Step 3: Update `_openClinicalForm` for iOS**

The `_currentTab` variable used by `_openClinicalForm` needs to map from `_iosSegment` on iOS:

```dart
Future<void> _openClinicalForm() async {
  // On iOS, map segmented control index to the logical tab index
  final tabIndex = kIsIOS
      ? _visibleIndices[_iosSegment]
      : _currentTab;
  // rest of the method uses tabIndex instead of _currentTab
```

Replace every reference to `_currentTab` inside `_openClinicalForm` with `tabIndex`.

- [ ] **Step 4: Verify**

```bash
flutter analyze lib/presentation/patients/screens/patient_detail_screen.dart 2>&1
```
Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/patients/screens/patient_detail_screen.dart
git commit -m "feat(mobile): CupertinoSlidingSegmentedControl replaces TabBar on iOS in PatientDetailScreen"
```

---

## Task 10: Remaining small widgets

**Files:** all screens — search for `CircularProgressIndicator`, `LinearProgressIndicator`, `SearchBar`, `CupertinoSearchTextField`.

### CircularProgressIndicator → CupertinoActivityIndicator

```dart
kIsIOS
  ? const CupertinoActivityIndicator()
  : const CircularProgressIndicator()
```

Apply to: `android_shell.dart` (already done), `patient_list_screen.dart`, `access_grants_screen.dart`, `emergency_access_screen.dart`, `clinical_record_tab.dart`, `roster_screen.dart`, `reporting_screen.dart`, `billing_invoices_screen.dart`, `staff_profile_screen.dart`.

Run to find all occurrences:
```bash
grep -rln "CircularProgressIndicator" lib/presentation/ --include="*.dart"
```

### Search bar — PatientListScreen

`patient_list_screen.dart` uses a `TextField` or `SearchBar` for searching. On iOS replace with:

```dart
kIsIOS
  ? Padding(
      padding: const EdgeInsets.all(8),
      child: CupertinoSearchTextField(
        controller: _searchCtrl,
        onChanged: (v) => patientProvider.search(v),
        onSubmitted: (v) => patientProvider.search(v),
      ),
    )
  : TextField(
      controller: _searchCtrl,
      // existing
    )
```

- [ ] **Step 1: Replace CircularProgressIndicator in all screens**

- [ ] **Step 2: Replace search bar in `patient_list_screen.dart`**

- [ ] **Step 3: Final full analyze**

```bash
flutter analyze lib/ 2>&1 | grep -E "^error|^warning"
```
Expected: zero errors, zero warnings.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/
git commit -m "feat(mobile): CupertinoActivityIndicator and CupertinoSearchTextField on iOS"
```

---

## Self-Review

### Spec coverage

| Spec requirement | Task |
|---|---|
| `kIsIOS` single source of truth | Task 2 |
| `AppColors` shared constants | Task 1 |
| `showAdaptiveDialog` | Task 2 |
| `showAdaptiveActionSheet` | Task 2 |
| `AdaptiveToast` | Task 2 |
| `AndroidShell` (MaterialApp + Drawer) | Task 3 |
| `IOSShell` (CupertinoApp + CupertinoTabScaffold) | Task 3 |
| 4 tabs: Patients, Roster, Access, More | Task 3 |
| `MoreScreen` with Settings-style sections | Task 3 |
| Each tab has independent navigation stack | Task 3 (`CupertinoTabView`) |
| Frosted white nav bar, large title on list screens | Task 4 |
| Compact nav bar on detail screens | Task 4 |
| `CupertinoPageRoute` on iOS | Task 4 |
| `CupertinoButton.filled` for primary | Task 5 |
| `CupertinoButton` for text/cancel | Task 5 |
| Sentence case on iOS buttons | Task 5 |
| FAB → nav bar trailing on iOS | Task 9 (PatientDetailScreen) |
| `showAdaptiveDialog` replaces all `showDialog` | Task 6 |
| `showAdaptiveActionSheet` replaces destructive confirms | Task 6 |
| `showAdaptiveToast` replaces all SnackBars | Task 6 |
| `CupertinoTextField` in forms | Task 7 |
| `CupertinoActionSheet` picker for dropdowns | Task 7 |
| `CupertinoSwitch` | Task 7 |
| `CupertinoListSection.insetGrouped` + `CupertinoListTile` | Task 8 |
| `Dismissible` swipe-to-delete on clinical lists | Task 8 |
| `CupertinoSliverRefreshControl` | Task 8 |
| `CupertinoSlidingSegmentedControl` in PatientDetailScreen | Task 9 |
| `IndexedStack` (keeps state per tab) | Task 9 |
| `CupertinoActivityIndicator` | Task 10 |
| `CupertinoSearchTextField` | Task 10 |
| Android experience: zero regression | All tasks — Android path preserved in every conditional |
| Data/repo/provider layer: untouched | All tasks — only presentation layer modified |

All spec requirements covered. No gaps.
