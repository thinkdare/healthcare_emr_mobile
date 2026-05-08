# Dashboard Profile Dropdown Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove `_StaffInfoCard` and `_FacilityCard` from the dashboard scroll list and replace the logout icon in the AppBar with a dropdown menu (Profile / Settings / Logout).

**Architecture:** Two files change: `provider_dashboard_screen.dart` loses the two bottom cards and its logout AppBar action; `staff_profile_screen.dart` gains an optional `initialTab` parameter so Settings can open directly on the Security tab. No new files are created.

**Tech Stack:** Flutter, Material (PopupMenuButton), Cupertino (CupertinoActionSheet), Provider

---

## File Map

| File | Change |
|---|---|
| `lib/presentation/dashboard/screens/provider_dashboard_screen.dart` | Remove `_StaffInfoCard` + `_FacilityCard` from scroll list; replace logout icon with `PopupMenuButton` (Material) and person-icon `CupertinoButton` → `CupertinoActionSheet` (iOS) |
| `lib/presentation/profile/screens/staff_profile_screen.dart` | Add optional `initialTab` parameter (default `0`) threaded through to `TabController` |

---

## Task 1: Add `initialTab` to `StaffProfileScreen`

**Files:**
- Modify: `lib/presentation/profile/screens/staff_profile_screen.dart:9-59`

- [ ] **Step 1: Add `initialTab` parameter to the widget constructor**

Replace the class declaration and `createState` at the top of the file:

```dart
class StaffProfileScreen extends StatefulWidget {
  final int initialTab;
  const StaffProfileScreen({super.key, this.initialTab = 0});

  @override
  State<StaffProfileScreen> createState() => _StaffProfileScreenState();
}
```

- [ ] **Step 2: Pass `initialTab` to the `TabController`**

In `_StaffProfileScreenState.initState`, change:

```dart
_tabs = TabController(length: 3, vsync: this);
```

to:

```dart
_tabs = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
```

- [ ] **Step 3: Verify the app compiles**

```bash
cd /home/dh/Forge/sandbox/healthcare_emr_mobile
flutter analyze lib/presentation/profile/screens/staff_profile_screen.dart
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/profile/screens/staff_profile_screen.dart
git commit -m "feat: add initialTab parameter to StaffProfileScreen"
```

---

## Task 2: Remove `_StaffInfoCard` and `_FacilityCard` from the dashboard scroll list

**Files:**
- Modify: `lib/presentation/dashboard/screens/provider_dashboard_screen.dart:170-177`

- [ ] **Step 1: Remove the two cards from the `Column` children in the `RefreshIndicator` body**

In the `Column` inside `SingleChildScrollView`, find and remove these lines (around line 173–177):

```dart
                        const SizedBox(height: 16),
                        _StaffInfoCard(auth: auth),
                        const SizedBox(height: 16),
                        _FacilityCard(auth: auth),
```

The `Column` children list should end at `_EmergencyAccessCard` (plus its preceding `SizedBox`). After the edit the tail of the list looks like:

```dart
                        if (showEmergency) ...[
                          const SizedBox(height: 16),
                          _EmergencyAccessCard(),
                        ],
```

- [ ] **Step 2: Verify the app compiles**

```bash
flutter analyze lib/presentation/dashboard/screens/provider_dashboard_screen.dart
```

Expected: no errors. (The `_StaffInfoCard` and `_FacilityCard` class definitions lower in the file are still there — leave them; they will be cleaned up in a follow-up if desired, but they do no harm and removing them is out of scope.)

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/dashboard/screens/provider_dashboard_screen.dart
git commit -m "feat: remove staff profile and facility cards from dashboard scroll list"
```

---

## Task 3: Replace logout icon with dropdown (Material `PopupMenuButton`)

**Files:**
- Modify: `lib/presentation/dashboard/screens/provider_dashboard_screen.dart:119-127`

- [ ] **Step 1: Replace the `IconButton` logout action in the Material `AppBar`**

Find this block (around lines 119–127):

```dart
          : AppBar(
              title: const Text('Dashboard'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: 'Logout',
                  onPressed: () => _handleLogout(context),
                ),
              ],
            ),
```

Replace it with:

```dart
          : AppBar(
              title: const Text('Dashboard'),
              actions: [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.account_circle_outlined),
                  tooltip: 'Account',
                  onSelected: (value) {
                    switch (value) {
                      case 'profile':
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const StaffProfileScreen()));
                      case 'settings':
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) =>
                                const StaffProfileScreen(initialTab: 1)));
                      case 'logout':
                        _handleLogout(context);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'profile',
                      child: ListTile(
                        leading: Icon(Icons.person_outline),
                        title: Text('Profile'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'settings',
                      child: ListTile(
                        leading: Icon(Icons.settings_outlined),
                        title: Text('Settings'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'logout',
                      child: ListTile(
                        leading: Icon(Icons.logout, color: AppTheme.errorColor),
                        title: Text('Logout',
                            style: TextStyle(color: AppTheme.errorColor)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
```

- [ ] **Step 2: Verify the app compiles**

```bash
flutter analyze lib/presentation/dashboard/screens/provider_dashboard_screen.dart
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/dashboard/screens/provider_dashboard_screen.dart
git commit -m "feat: replace dashboard logout icon with account dropdown (Material)"
```

---

## Task 4: Replace logout icon with dropdown (iOS `CupertinoActionSheet`)

**Files:**
- Modify: `lib/presentation/dashboard/screens/provider_dashboard_screen.dart:110-118`

- [ ] **Step 1: Add a helper method `_showAccountMenu` to `_ProviderDashboardScreenState`**

Add this method directly above `_handleLogout`:

```dart
  Future<void> _showAccountMenu(BuildContext context) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(CupertinoPageRoute(
                  builder: (_) => const StaffProfileScreen()));
            },
            child: const Text('Profile'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(CupertinoPageRoute(
                  builder: (_) => const StaffProfileScreen(initialTab: 1)));
            },
            child: const Text('Settings'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              _handleLogout(context);
            },
            child: const Text('Logout'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
```

- [ ] **Step 2: Replace the `CupertinoNavigationBar` trailing widget**

Find this block (around lines 110–118):

```dart
      appBar: kIsIOS
          ? CupertinoNavigationBar(
              middle: const Text('Dashboard'),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _handleLogout(context),
                child: const Icon(CupertinoIcons.square_arrow_left),
              ),
            )
```

Replace it with:

```dart
      appBar: kIsIOS
          ? CupertinoNavigationBar(
              middle: const Text('Dashboard'),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _showAccountMenu(context),
                child: const Icon(CupertinoIcons.person_circle),
              ),
            )
```

- [ ] **Step 3: Verify the app compiles**

```bash
flutter analyze lib/presentation/dashboard/screens/provider_dashboard_screen.dart
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/dashboard/screens/provider_dashboard_screen.dart
git commit -m "feat: replace dashboard logout icon with account menu (iOS Cupertino)"
```

---

## Task 5: Manual smoke test

- [ ] **Step 1: Run the app**

```bash
flutter run
```

- [ ] **Step 2: Verify on Material (Android emulator or physical device)**

1. Log in — dashboard should load without Staff Profile or Active Facility cards at the bottom.
2. Tap the account circle icon (top right) — dropdown should appear with Profile, Settings, Logout.
3. Tap **Profile** — `StaffProfileScreen` opens on the Profile tab.
4. Back → tap **Settings** — `StaffProfileScreen` opens on the Security tab.
5. Back → tap **Logout** — confirmation sheet appears; confirm → returns to login screen.

- [ ] **Step 3: Verify on iOS simulator**

1. Log in — same dashboard check (no cards at bottom).
2. Tap person circle icon (top right) — `CupertinoActionSheet` appears with Profile, Settings, Logout, Cancel.
3. Tap **Profile** → profile screen, Profile tab.
4. Back → **Settings** → profile screen, Security tab.
5. Back → **Logout** → confirm → login screen.

- [ ] **Step 4: Final commit (if any last-minute tweaks were made)**

```bash
git add -p
git commit -m "fix: dashboard profile dropdown smoke test tweaks"
```
