# Org Admin Shell & Screens — Design Spec
**Date:** 2026-05-28
**App:** healthcare_emr_mobile (Flutter)
**Branch:** dev

---

## Overview

Org admins currently share the clinical staff shell (tabs/drawer designed for doctors and nurses). This spec adds a dedicated org admin experience across three surfaces: iOS mobile, Android mobile, and Flutter Web. The web shell uses a collapsible sidebar. Mobile shells use bottom tabs. All four tab destinations are the same across surfaces.

Scope: org admin shell routing, one new dashboard screen, one trimmed More screen, web shell with collapsible sidebar, and adaptive-widget fixes on two existing screens.

---

## Backend endpoints consumed

All already wired in the repository layer:

| Purpose | Endpoint |
|---------|----------|
| Org detail + facilities list | `GET /api/v1/organizations/{id}` |
| Org aggregate stats | `GET /api/v1/organizations/{id}/stats` |
| Update org | `PUT /api/v1/organizations/{id}` |
| Facilities CRUD | `GET/POST/PUT/DELETE /api/v1/tenants/*` |
| Staff list + bulk actions | `GET /api/v1/tenants/{id}/staff`, `POST /api/v1/tenants/{id}/staff/bulk-suspend` |
| Staff invite | `POST /api/v1/staff/invite` |
| Subscription & billing | `/api/v1/billing/organizations/{orgId}/*` |
| Reporting dashboard | `GET /api/v1/reporting/organizations/{orgId}/dashboard` |

---

## Shell routing

`main.dart` currently branches on `kIsIOS`. Replace with a three-way platform check:

```
kIsWeb                     → OrgAdminWebShell    (auth.isOrgAdmin)
                           → ClinicalWebShell    (staff — future, out of scope here)
!kIsWeb && kIsIOS          → IOSShell            (internally branches on isOrgAdmin)
!kIsWeb && !kIsIOS         → AndroidShell        (internally branches on isOrgAdmin)
```

Note: `kIsIOS` is a project-defined getter in `lib/core/platform.dart` (`!kIsWeb && Platform.isIOS`), not Flutter's framework constant. It is already web-safe and the three-way branch above is correct.

`IOSShell` and `AndroidShell` each watch `AuthProvider.isOrgAdmin` and render the org admin shell variant when true; otherwise render their existing clinical shell unchanged.

**Authorization model:** Shell-level routing is a UI gate only, not an authorization control. Each org admin screen calls the backend directly — the backend enforces role checks on every endpoint and returns 401/403 for unauthorized requests. The existing `_ErrorView` pattern handles these failures. No widget-layer role guard is needed in org admin screens; the backend is the authority.

---

## Tab structure (all platforms)

Four tabs, identical destinations on all three shells:

| # | Label | Screen | Icon (Material / Cupertino) |
|---|-------|---------|----------------------------|
| 1 | Overview | `OrgDashboardScreen` (new) | `business_center` / `CupertinoIcons.building_2_fill` |
| 2 | Facilities | `FacilitiesListScreen` (existing, adaptive fixes) | `apartment` / `CupertinoIcons.house_fill` |
| 3 | Staff | `StaffManagementScreen` (existing) | `group` / `CupertinoIcons.person_2_fill` |
| 4 | More | `OrgAdminMoreScreen` (new, mobile only) | `more_horiz` / `CupertinoIcons.ellipsis` |

On **web**, the More tab is replaced by sidebar footer actions (see Web Shell section). There are only 3 primary nav items in the sidebar; secondary actions live in the sidebar footer.

---

## New files

### `OrgAdminIOSShell` — `lib/presentation/shell/org_admin_ios_shell.dart`

`CupertinoTabScaffold` with four `CupertinoTabView` entries matching the tab table above. Mirrors the structure of `ios_shell.dart`. Org admin tabs use `CupertinoColors.systemOrange` as the active tab tint to visually distinguish from the clinical shell.

### `OrgAdminAndroidShell` — `lib/presentation/shell/org_admin_android_shell.dart`

`Scaffold` with `BottomNavigationBar` (4 items, same 4 as iOS). No drawer. Uses `AppTheme.primaryColor` for selected items. The 4th tab renders `OrgAdminMoreScreen` which is adaptive (see below). Mirrors `android_shell.dart` structure.

### `OrgAdminWebShell` — `lib/presentation/shell/org_admin_web_shell.dart`

`Scaffold` with a `Row` of:
- `_OrgAdminSidebar` (collapsible `NavigationRail`)
- `VerticalDivider`
- `Expanded(child: IndexedStack(…))` — the active tab body

**Sidebar behaviour:**
- Default state: expanded (icon + label, `extended: true` on `NavigationRail`)
- Collapse toggle: `IconButton` in the sidebar header (`menu` / `menu_open` icon)
- Collapsed state: icon only (`extended: false`), rail width shrinks to standard
- Sidebar stores its open/closed state in local `StatefulWidget` state (no provider needed)
- 3 primary `NavigationRailDestination` items: Overview, Facilities, Staff
- Footer: vertical column of `IconButton`s (or `TextButton`s when expanded) for: Organisation Profile, Subscription & Billing, Reporting, Sign Out
- Sidebar background: `Colors.white` with a right border; no elevation
- Collapsed state: `NavigationRail` at default 72 dp width. The footer column must set `overflow: Overflow.clip` (or wrap in `ClipRect`) to prevent label text bleeding during the expand/collapse animation. The collapse toggle `IconButton` sits above the rail destinations in the `leading` slot.

**Content area:**
- Each tab body renders the existing screen directly inside `IndexedStack`. Flutter permits nested `Scaffold`s, so screens keep their own `AppBar` on web — the web shell does not own an AppBar. This avoids needing a separate "embedded" widget variant for each screen.
- Screens already have responsive breakpoints (`isWeb` checks for grid vs list layouts) — these remain in place.

### `OrgDashboardScreen` — `lib/presentation/organization/screens/org_dashboard_screen.dart`

The Overview tab home for org admins. Loads org detail + stats in parallel on `initState` (same pattern as `OrganizationProfileScreen._load()`).

**Layout — mobile:**
- Gradient header (matches `_StatsHeader` in `OrganizationProfileScreen`): org name, type, subscription badge
- Three stat tiles in a row: Facilities, Staff, Patients (from `OrgStatsModel`)
- Subscription status banner below header — shows trial days remaining (amber) or active (green) or expired (red), tappable → `SubscriptionDetailsScreen`
- Section: "Quick Actions" — 2×2 grid of tappable tiles: Manage Facilities, Manage Staff, Subscription & Billing, Reports
- Section: "Facilities" — horizontal scroll list of facility cards (name, type, active badge) from `org.facilities`; "See all" → `FacilitiesListScreen`

**Layout — web (wide screen):**
- Same structure but stat tiles expand to 4 columns (add an `Active Facilities` count)
- Quick Actions become a 4-column row
- Facilities section becomes a full-width list below

**Data:**
- Uses `OrganizationRepository` (injected, same as `OrganizationProfileScreen`)
- No new provider state needed — screen manages its own load state

**Error/loading:**
- Full-screen `CircularProgressIndicator` on load
- `_ErrorView` widget extracted to `lib/presentation/common/error_view.dart` and reused here and in `OrganizationProfileScreen` (do not copy — extract once, import everywhere)
- Stats section degrades gracefully if stats endpoint fails (shows `—` with warning icon)

### `OrgAdminMoreScreen` — `lib/presentation/more/org_admin_more_screen.dart`

Used as the 4th tab on both iOS and Android. Web uses the sidebar footer instead (this screen is not shown on web). Adaptive: Cupertino list sections on iOS, Material `ListView` with `ListTile` on Android.

Sections:
1. **Admin** (orange header on iOS / section divider on Android): Organisation Profile, Invite Staff *(Facilities and Staff are already tab 2 and tab 3 — do not duplicate them here)*
2. **Account**: Subscription & Billing, Reporting & Compliance, Staff Profile
3. *(no sync or referrals — not relevant to org admins)*
4. Sign Out (destructive)

iOS: `CupertinoListSection.insetGrouped` + `CupertinoListTile` + `CupertinoPageRoute`.
Android: `ListView` + `ListTile` + `MaterialPageRoute`.

---

## Adaptive fixes on existing screens

### `OrganizationProfileScreen`

| Issue | Fix |
|-------|-----|
| Uses plain `AppBar` on all platforms | Branch on `kIsIOS`: `CupertinoNavigationBar` with Cancel/Save actions in the nav bar; `AppBar` on Android/web |
| `ScaffoldMessenger.showSnackBar` on save error | Replace with `showAdaptiveToast(context, message, type: ToastType.error)` |
| Org type values don't match backend | Replace `_orgTypes` list with backend enum values: `state`, `federal`, `private_group`, `ngo`, `standalone` |

### `FacilitiesListScreen`

| Issue | Fix |
|-------|-----|
| Uses plain `AppBar` on all platforms | Branch on `kIsIOS`: `CupertinoNavigationBar` with trailing refresh button |
| `PopupMenuButton` for edit/delete | On iOS: `showAdaptiveActionSheet`; on Android/web: keep `PopupMenuButton` |
| FAB uses `FloatingActionButton.extended` | On iOS: move add action to `CupertinoNavigationBar` trailing `+` button; keep FAB on Android/web |

---

## Files to create

| File | Purpose |
|------|---------|
| `lib/presentation/shell/org_admin_ios_shell.dart` | iOS tab shell for org admins |
| `lib/presentation/shell/org_admin_android_shell.dart` | Android bottom-nav shell |
| `lib/presentation/shell/org_admin_web_shell.dart` | Web collapsible sidebar shell |
| `lib/presentation/organization/screens/org_dashboard_screen.dart` | Overview tab home |
| `lib/presentation/more/org_admin_more_screen.dart` | More tab (iOS + Android, org admin) |
| `lib/presentation/common/error_view.dart` | Shared `ErrorView` widget (extracted from `OrganizationProfileScreen`) |

## Files to modify

| File | Change |
|------|--------|
| `lib/main.dart` | Add `kIsWeb` branch; route `isOrgAdmin` to org admin shells |
| `lib/presentation/shell/ios_shell.dart` | Check `isOrgAdmin` → render `OrgAdminIOSShell` |
| `lib/presentation/shell/android_shell.dart` | Check `isOrgAdmin` → render `OrgAdminAndroidShell` |
| `lib/presentation/organization/screens/organization_profile_screen.dart` | Adaptive nav bar, toast on error, correct org type enums (`state`/`federal`/`private_group`/`ngo`/`standalone`), replace inline `_ErrorView` with shared `ErrorView` |
| `lib/presentation/facilities/screens/facilities_list_screen.dart` | Adaptive nav bar, adaptive delete action, iOS FAB→nav button |

---

## Out of scope

- Clinical staff web shell (separate task)
- Push notification routing for org admin events
- Offline/SQLite caching for org admin data (org admins are expected to be online)
- Super admin CRUD on organizations (Blade admin panel, separate surface)
