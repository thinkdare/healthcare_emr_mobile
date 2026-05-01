# Task 7: Adaptive Forms + Inputs

**Date:** 2026-05-01
**Branch:** dev
**Sprint:** Platform-Adaptive UI (iOS Cupertino / Android Material)

---

## Scope

Convert `DropdownButtonFormField` → `AdaptiveDropdown<T>` (CupertinoActionSheet on iOS, unchanged on Android) and `Switch` → inline `kIsIOS` branch across all presentation files. `TextFormField` is explicitly out of scope — text inputs render acceptably on both platforms and the Form validation risk is not worth the effort.

---

## New Widget: `AdaptiveDropdown<T>` (platform.dart)

### Signature

```dart
class AdaptiveDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final InputDecoration decoration;
  final String? Function(T?)? validator;

  const AdaptiveDropdown({ ... });
}
```

### Android path

Renders `DropdownButtonFormField<T>` with all parameters passed through unchanged. No behavioural difference from the current code.

### iOS path

Renders a `FormField<T>` whose builder produces a tappable row:

- Label text drawn above (from `decoration.labelText`)
- Current selection label (or a greyed placeholder if null) + trailing `CupertinoIcons.chevron_down` drawn below
- On tap: `showCupertinoModalPopup` opens a `CupertinoActionSheet`
  - Each `DropdownMenuItem<T>` child label becomes a `CupertinoActionSheetAction`
  - Tapping an action calls `onChanged(item.value)`, calls `state.didChange(item.value)`, then dismisses
  - A Cancel button is always present and only dismisses
- If `validator` is provided and `state.hasError` is true, the error text is shown below the row in red (matching Material error style)
- `FormField.validator` calls `validator?.call(state.value)` so `Form.validate()` works correctly

### Label extraction

Items are `DropdownMenuItem<T>` whose `child` is a `Text` widget. The iOS row reads the current selection label by finding the matching item and casting its child to `Text`. If the child is not `Text`, the raw `value.toString()` is used as fallback.

---

## Switch Adaptation

One call site in `facility_form_screen.dart`. Replace:

```dart
Switch(value: _supportsEmergencyAccess, onChanged: (v) { ... })
```

with:

```dart
kIsIOS
  ? CupertinoSwitch(value: _supportsEmergencyAccess, onChanged: (v) { ... })
  : Switch(value: _supportsEmergencyAccess, onChanged: (v) { ... })
```

No wrapper widget. The duplication is acceptable for a single site.

---

## Files Changed

| File | Dropdowns | Switch |
|------|-----------|--------|
| `lib/core/platform.dart` | add `AdaptiveDropdown<T>` | — |
| `lib/presentation/facilities/screens/facility_form_screen.dart` | 1 | 1 |
| `lib/presentation/providers/screens/provider_invitation_screen.dart` | 2 | — |
| `lib/presentation/auth/screens/login_screen.dart` | 1 | — |
| `lib/presentation/access_grants/screens/request_access_screen.dart` | 1 | — |
| `lib/presentation/emergency_access/screens/trigger_emergency_access_screen.dart` | 1 | — |
| `lib/presentation/reporting/screens/reporting_screen.dart` | 3 | — |
| `lib/presentation/patients/screens/patient_form_screen.dart` | 2 | — |
| `lib/presentation/patients/widgets/clinical_forms.dart` | 5 | — |
| `lib/presentation/patients/widgets/clinical_record_forms.dart` | 5 | — |

**Total:** 21 dropdowns + 1 switch across 10 files.

---

## Out of Scope

- `TextFormField` → `CupertinoTextField` (excluded — Form validation risk, low visual payoff)
- `CheckboxListTile` (acceptable on iOS as-is)
- `OutlinedButton` (already covered by Task 5)
- `DropdownMenuItem` definitions (reused unchanged on Android; labels extracted on iOS)

---

## Verification

After implementation: `flutter analyze --no-pub` must report 0 errors. Manual smoke test on iOS simulator: open a form with a dropdown, confirm the action sheet appears with all options, select one, confirm it populates correctly and Form validation fires on submit.
