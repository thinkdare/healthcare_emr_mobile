# Task 7: Adaptive Forms + Inputs — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all 21 `DropdownButtonFormField` usages with a new `AdaptiveDropdown<T>` widget (CupertinoActionSheet on iOS, unchanged on Android) and adapt the one `Switch` in `facility_form_screen.dart` to `CupertinoSwitch` on iOS.

**Architecture:** A single new widget class `AdaptiveDropdown<T>` added to `lib/core/platform.dart` handles both platforms. Android renders `DropdownButtonFormField<T>` unchanged. iOS renders a `FormField<T>` with a tappable row that opens a `CupertinoActionSheet`; `state.didChange` + `onChanged` are both called to keep FormField validation state and parent widget state in sync. An optional `labelBuilder` parameter handles the one call site where the dropdown item child is not a plain `Text` widget.

**Tech Stack:** Flutter 3.10+ / Dart 3.0+, `package:flutter/cupertino.dart`, `package:flutter/material.dart`

---

## File Map

| File | Action | Details |
|------|--------|---------|
| `lib/core/platform.dart` | Modify | Add `AdaptiveDropdown<T>` class; add 3 symbols to material show-import |
| `lib/presentation/facilities/screens/facility_form_screen.dart` | Modify | 1 dropdown → AdaptiveDropdown; Switch → kIsIOS branch |
| `lib/presentation/access_grants/screens/request_access_screen.dart` | Modify | 1 dropdown (initialValue→value) |
| `lib/presentation/emergency_access/screens/trigger_emergency_access_screen.dart` | Modify | 1 dropdown (initialValue→value) |
| `lib/presentation/auth/screens/login_screen.dart` | Modify | 1 dropdown with labelBuilder (Column child) |
| `lib/presentation/providers/screens/provider_invitation_screen.dart` | Modify | 2 dropdowns |
| `lib/presentation/reporting/screens/reporting_screen.dart` | Modify | 3 dropdowns (nullable String? and bool? types) |
| `lib/presentation/patients/screens/patient_form_screen.dart` | Modify | 1 generic helper + 1 inline dropdown |
| `lib/presentation/patients/widgets/clinical_forms.dart` | Modify | 5 dropdowns (initialValue→value) |
| `lib/presentation/patients/widgets/clinical_record_forms.dart` | Modify | 5 dropdowns (initialValue→value) |

---

## Task 1: Add `AdaptiveDropdown<T>` to `platform.dart`

**Files:**
- Modify: `lib/core/platform.dart`

- [ ] **Step 1: Extend the material show-import to include the three new symbols**

In `lib/core/platform.dart`, replace the existing `import 'package:flutter/material.dart' show ...;` block with:

```dart
import 'package:flutter/material.dart'
    show
        AlertDialog,
        Colors,
        DropdownButtonFormField,
        DropdownMenuItem,
        ElevatedButton,
        Icon,
        Icons,
        InputDecoration,
        ListTile,
        Material,
        Navigator,
        OverlayEntry,
        Positioned,
        SafeArea,
        ScaffoldMessenger,
        SnackBar,
        StatelessWidget,
        TextButton,
        showDialog,
        showModalBottomSheet;
```

- [ ] **Step 2: Append `AdaptiveDropdown<T>` at the end of `platform.dart`**

Add the following block after the closing `}` of `AdaptiveTextButton`:

```dart
// ── Adaptive dropdown ─────────────────────────────────────────────────────────

/// Form dropdown: [DropdownButtonFormField] on Android; a tappable row backed
/// by [CupertinoActionSheet] on iOS.
///
/// The iOS row displays the selected item's label. Labels are extracted by
/// casting the matching [DropdownMenuItem.child] to [Text]. For items whose
/// child is not [Text] (e.g. a multi-line [Column]), pass [labelBuilder] to
/// provide the display string explicitly.
///
/// Both [state.didChange] and [onChanged] are called on selection so that
/// [Form.validate()] sees the correct value and the parent widget's
/// [setState] also fires.
class AdaptiveDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final InputDecoration decoration;
  final String? Function(T?)? validator;

  /// Optional: provide when [DropdownMenuItem.child] is not a [Text] widget.
  final String Function(T value)? labelBuilder;

  const AdaptiveDropdown({
    super.key,
    this.value,
    required this.items,
    this.onChanged,
    required this.decoration,
    this.validator,
    this.labelBuilder,
  });

  String _labelFor(T? val) {
    if (labelBuilder != null && val != null) return labelBuilder!(val as T);
    final match = items.where((item) => item.value == val).firstOrNull;
    if (match == null) return val?.toString() ?? '';
    final child = match.child;
    if (child is Text) return child.data ?? val?.toString() ?? '';
    return val?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsIOS) {
      return DropdownButtonFormField<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        decoration: decoration,
        validator: validator,
      );
    }

    // iOS: FormField + CupertinoActionSheet
    return FormField<T>(
      initialValue: value,
      validator: validator,
      builder: (state) {
        final currentLabel = _labelFor(state.value);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (decoration.labelText != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  decoration.labelText!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ),
            GestureDetector(
              onTap: () => showCupertinoModalPopup<void>(
                context: context,
                builder: (_) => CupertinoActionSheet(
                  actions: items.map((item) {
                    return CupertinoActionSheetAction(
                      onPressed: () {
                        Navigator.of(context).pop();
                        state.didChange(item.value);
                        onChanged?.call(item.value);
                      },
                      child: item.child,
                    );
                  }).toList(),
                  cancelButton: CupertinoActionSheetAction(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: state.hasError
                          ? CupertinoColors.systemRed
                          : CupertinoColors.separator,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: currentLabel.isEmpty
                          ? Text(
                              decoration.hintText ?? '',
                              style: const TextStyle(
                                  color: CupertinoColors.placeholderText),
                            )
                          : Text(currentLabel),
                    ),
                    const Icon(
                      CupertinoIcons.chevron_down,
                      size: 16,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ],
                ),
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  state.errorText!,
                  style: const TextStyle(
                    color: CupertinoColors.systemRed,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
```

- [ ] **Step 3: Verify — 0 analyzer errors**

```bash
cd /home/dh/Forge/sandbox/healthcare_emr_mobile
flutter analyze --no-pub lib/core/platform.dart
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/core/platform.dart
git commit -m "feat: add AdaptiveDropdown<T> widget to platform.dart"
```

---

## Task 2: Migrate `facility_form_screen.dart` (1 dropdown + 1 switch)

**Files:**
- Modify: `lib/presentation/facilities/screens/facility_form_screen.dart`

Current state (lines 192–223): one `DropdownButtonFormField<String>` for Facility Type; no validator.
Current state (lines 293–298): one `Switch`.

- [ ] **Step 1: Replace the Facility Type dropdown**

Find and replace (lines ~192–223):

```dart
                          // Type
                          DropdownButtonFormField<String>(
                            value: _selectedType,
                            decoration: const InputDecoration(
                              labelText: 'Facility Type *',
                              prefixIcon: Icon(Icons.category),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'main_hospital',
                                child: Text('Main Hospital'),
                              ),
                              DropdownMenuItem(
                                value: 'branch',
                                child: Text('Branch'),
                              ),
                              DropdownMenuItem(
                                value: 'pharmacy',
                                child: Text('Pharmacy'),
                              ),
                              DropdownMenuItem(
                                value: 'lab',
                                child: Text('Laboratory'),
                              ),
                              DropdownMenuItem(
                                value: 'diagnostic_center',
                                child: Text('Diagnostic Center'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedType = value!);
                            },
                          ),
```

→

```dart
                          // Type
                          AdaptiveDropdown<String>(
                            value: _selectedType,
                            decoration: const InputDecoration(
                              labelText: 'Facility Type *',
                              prefixIcon: Icon(Icons.category),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'main_hospital',
                                child: Text('Main Hospital'),
                              ),
                              DropdownMenuItem(
                                value: 'branch',
                                child: Text('Branch'),
                              ),
                              DropdownMenuItem(
                                value: 'pharmacy',
                                child: Text('Pharmacy'),
                              ),
                              DropdownMenuItem(
                                value: 'lab',
                                child: Text('Laboratory'),
                              ),
                              DropdownMenuItem(
                                value: 'diagnostic_center',
                                child: Text('Diagnostic Center'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedType = value!);
                            },
                          ),
```

- [ ] **Step 2: Replace the Switch with an inline kIsIOS branch**

Find (lines ~293–298):

```dart
                                Switch(
                                  value: _supportsEmergencyAccess,
                                  onChanged: (value) {
                                    setState(() => _supportsEmergencyAccess = value);
                                  },
                                ),
```

→

```dart
                                kIsIOS
                                    ? CupertinoSwitch(
                                        value: _supportsEmergencyAccess,
                                        onChanged: (value) {
                                          setState(() => _supportsEmergencyAccess = value);
                                        },
                                      )
                                    : Switch(
                                        value: _supportsEmergencyAccess,
                                        onChanged: (value) {
                                          setState(() => _supportsEmergencyAccess = value);
                                        },
                                      ),
```

- [ ] **Step 3: Verify**

```bash
flutter analyze --no-pub lib/presentation/facilities/screens/facility_form_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/facilities/screens/facility_form_screen.dart
git commit -m "feat(task7): migrate facility_form_screen dropdown + switch to adaptive"
```

---

## Task 3: Migrate `request_access_screen.dart` + `trigger_emergency_access_screen.dart`

**Files:**
- Modify: `lib/presentation/access_grants/screens/request_access_screen.dart`
- Modify: `lib/presentation/emergency_access/screens/trigger_emergency_access_screen.dart`

Both files already import `platform.dart`. Both dropdowns use `initialValue:` which becomes `value:` in `AdaptiveDropdown` (the backing state variable is always kept current by `onChanged`).

- [ ] **Step 1: Migrate `request_access_screen.dart` (line 208)**

Find:

```dart
              DropdownButtonFormField<String>(
                initialValue: _accessLevel,
                decoration:
                    const InputDecoration(labelText: 'Access Level *'),
                items: _accessLevels
                    .map((l) => DropdownMenuItem(
                        value: l.$1, child: Text(l.$2)))
                    .toList(),
                onChanged: (v) => setState(() => _accessLevel = v!),
              ),
```

→

```dart
              AdaptiveDropdown<String>(
                value: _accessLevel,
                decoration:
                    const InputDecoration(labelText: 'Access Level *'),
                items: _accessLevels
                    .map((l) => DropdownMenuItem(
                        value: l.$1, child: Text(l.$2)))
                    .toList(),
                onChanged: (v) => setState(() => _accessLevel = v!),
              ),
```

- [ ] **Step 2: Migrate `trigger_emergency_access_screen.dart` (line 208)**

Find:

```dart
              DropdownButtonFormField<String>(
                initialValue: _emergencyType,
                decoration:
                    const InputDecoration(labelText: 'Emergency Type *'),
                items: _types
                    .map((t) => DropdownMenuItem(
                        value: t.$1, child: Text(t.$2)))
                    .toList(),
                onChanged: (v) => setState(() => _emergencyType = v!),
              ),
```

→

```dart
              AdaptiveDropdown<String>(
                value: _emergencyType,
                decoration:
                    const InputDecoration(labelText: 'Emergency Type *'),
                items: _types
                    .map((t) => DropdownMenuItem(
                        value: t.$1, child: Text(t.$2)))
                    .toList(),
                onChanged: (v) => setState(() => _emergencyType = v!),
              ),
```

- [ ] **Step 3: Verify**

```bash
flutter analyze --no-pub \
  lib/presentation/access_grants/screens/request_access_screen.dart \
  lib/presentation/emergency_access/screens/trigger_emergency_access_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/access_grants/screens/request_access_screen.dart \
        lib/presentation/emergency_access/screens/trigger_emergency_access_screen.dart
git commit -m "feat(task7): migrate access_grants + emergency_access dropdowns to adaptive"
```

---

## Task 4: Migrate `login_screen.dart` (complex child — needs `labelBuilder`)

**Files:**
- Modify: `lib/presentation/auth/screens/login_screen.dart`

The dropdown items use a `Column(children: [Text(f.name), Text(f.organization!.name)])` child — not a plain `Text`. `_labelFor` would fall back to `AuthFacilityModel.toString()` which is unhelpful. Pass `labelBuilder: (f) => f.name` to display just the facility name in the iOS tappable row (the action sheet still shows the full `Column` child for each option).

The original widget also had a standalone `hint: const Text('Choose your facility')` property. Move this value into `decoration.hintText` since `AdaptiveDropdown` reads `decoration.hintText` for the iOS placeholder.

- [ ] **Step 1: Migrate `login_screen.dart` (line 426)**

Find:

```dart
    // Multiple facilities — dropdown selector
    return DropdownButtonFormField<AuthFacilityModel>(
      value: selected,
      decoration: const InputDecoration(
        labelText: 'Select Facility',
        prefixIcon: Icon(Icons.local_hospital_outlined),
      ),
      hint: const Text('Choose your facility'),
      items: facilities.map((f) {
        return DropdownMenuItem(
          value: f,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(f.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 14)),
              if (f.organization != null)
                Text(f.organization!.name,
                    style: TextStyle(fontSize: 12, color: AppTheme.gray600)),
            ],
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
```

→

```dart
    // Multiple facilities — dropdown selector
    return AdaptiveDropdown<AuthFacilityModel>(
      value: selected,
      decoration: const InputDecoration(
        labelText: 'Select Facility',
        prefixIcon: Icon(Icons.local_hospital_outlined),
        hintText: 'Choose your facility',
      ),
      items: facilities.map((f) {
        return DropdownMenuItem(
          value: f,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(f.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 14)),
              if (f.organization != null)
                Text(f.organization!.name,
                    style: TextStyle(fontSize: 12, color: AppTheme.gray600)),
            ],
          ),
        );
      }).toList(),
      onChanged: onChanged,
      labelBuilder: (f) => f.name,
    );
```

- [ ] **Step 2: Verify**

```bash
flutter analyze --no-pub lib/presentation/auth/screens/login_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/auth/screens/login_screen.dart
git commit -m "feat(task7): migrate login_screen facility dropdown to adaptive"
```

---

## Task 5: Migrate `provider_invitation_screen.dart` (2 dropdowns)

**Files:**
- Modify: `lib/presentation/providers/screens/provider_invitation_screen.dart`

Two dropdowns: Provider Type (line 253) and Assign to Facility (line 297). Both use `value:` and `Text` children. No validators.

- [ ] **Step 1: Replace Provider Type dropdown (line 253)**

Find:

```dart
                          DropdownButtonFormField<String>(
                            value: _selectedProviderType,
                            decoration: const InputDecoration(
                              labelText: 'Provider Type *',
                              prefixIcon: Icon(Icons.medical_services),
                            ),
                            items: AppConfig.providerTypeNames.entries.map((entry) {
                              return DropdownMenuItem(
                                value: entry.key,
                                child: Text(entry.value),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedProviderType = value!);
                            },
                          ),
```

→

```dart
                          AdaptiveDropdown<String>(
                            value: _selectedProviderType,
                            decoration: const InputDecoration(
                              labelText: 'Provider Type *',
                              prefixIcon: Icon(Icons.medical_services),
                            ),
                            items: AppConfig.providerTypeNames.entries.map((entry) {
                              return DropdownMenuItem(
                                value: entry.key,
                                child: Text(entry.value),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedProviderType = value!);
                            },
                          ),
```

- [ ] **Step 2: Replace Assign to Facility dropdown (line 297)**

Find:

```dart
                          DropdownButtonFormField<String>(
                            value: _selectedFacility,
                            decoration: const InputDecoration(
                              labelText: 'Assign to Facility *',
                              prefixIcon: Icon(Icons.business),
                            ),
                            items: const [
                              // TODO: Populate from facilities API
                              DropdownMenuItem(
                                value: 'facility_1',
                                child: Text('Main Hospital'),
                              ),
                              DropdownMenuItem(
                                value: 'facility_2',
                                child: Text('Downtown Branch'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedFacility = value!);
                            },
                          ),
```

→

```dart
                          AdaptiveDropdown<String>(
                            value: _selectedFacility,
                            decoration: const InputDecoration(
                              labelText: 'Assign to Facility *',
                              prefixIcon: Icon(Icons.business),
                            ),
                            items: const [
                              // TODO: Populate from facilities API
                              DropdownMenuItem(
                                value: 'facility_1',
                                child: Text('Main Hospital'),
                              ),
                              DropdownMenuItem(
                                value: 'facility_2',
                                child: Text('Downtown Branch'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedFacility = value!);
                            },
                          ),
```

- [ ] **Step 3: Verify**

```bash
flutter analyze --no-pub lib/presentation/providers/screens/provider_invitation_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/providers/screens/provider_invitation_screen.dart
git commit -m "feat(task7): migrate provider_invitation_screen dropdowns to adaptive"
```

---

## Task 6: Migrate `reporting_screen.dart` (3 dropdowns with nullable types)

**Files:**
- Modify: `lib/presentation/reporting/screens/reporting_screen.dart`

Three dropdowns inside a `StatefulBuilder` in a modal bottom sheet. Types are `String?` and `bool?` — nullable because `null` represents "All" selections. `AdaptiveDropdown<String?>` and `AdaptiveDropdown<bool?>` work correctly: `_labelFor` finds the matching `DropdownMenuItem` with `value: null` and extracts its `Text` child label ('All actions', 'All authorities', 'All events').

These dropdowns call `setLocal` (the `StatefulBuilder`'s setter), not the parent `setState`. `AdaptiveDropdown` passes `onChanged` through unchanged, so this works identically.

- [ ] **Step 1: Replace the Action filter dropdown (line 377)**

Find:

```dart
              DropdownButtonFormField<String?>(
                value: _actionFilter,
                decoration: const InputDecoration(labelText: 'Action'),
                items: _actions.map((a) => DropdownMenuItem(
                      value: a,
                      child: Text(a == null ? 'All actions' : _label(a)),
                    )).toList(),
                onChanged: (v) =>
                    setLocal(() => _actionFilter = v),
              ),
```

→

```dart
              AdaptiveDropdown<String?>(
                value: _actionFilter,
                decoration: const InputDecoration(labelText: 'Action'),
                items: _actions.map((a) => DropdownMenuItem(
                      value: a,
                      child: Text(a == null ? 'All actions' : _label(a)),
                    )).toList(),
                onChanged: (v) =>
                    setLocal(() => _actionFilter = v),
              ),
```

- [ ] **Step 2: Replace the Access authority filter dropdown (line 388)**

Find:

```dart
              DropdownButtonFormField<String?>(
                value: _authorityFilter,
                decoration:
                    const InputDecoration(labelText: 'Access authority'),
                items: _authorities.map((a) => DropdownMenuItem(
                      value: a,
                      child: Text(a == null
                          ? 'All authorities'
                          : _authorityLabel(a)),
                    )).toList(),
                onChanged: (v) =>
                    setLocal(() => _authorityFilter = v),
              ),
```

→

```dart
              AdaptiveDropdown<String?>(
                value: _authorityFilter,
                decoration:
                    const InputDecoration(labelText: 'Access authority'),
                items: _authorities.map((a) => DropdownMenuItem(
                      value: a,
                      child: Text(a == null
                          ? 'All authorities'
                          : _authorityLabel(a)),
                    )).toList(),
                onChanged: (v) =>
                    setLocal(() => _authorityFilter = v),
              ),
```

- [ ] **Step 3: Replace the Emergency events filter dropdown (line 402)**

Find:

```dart
              DropdownButtonFormField<bool?>(
                value: _emergencyFilter,
                decoration:
                    const InputDecoration(labelText: 'Emergency events'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All events')),
                  DropdownMenuItem(
                      value: true,
                      child: Text('Emergency only')),
                  DropdownMenuItem(
                      value: false,
                      child: Text('Non-emergency only')),
                ],
                onChanged: (v) =>
                    setLocal(() => _emergencyFilter = v),
              ),
```

→

```dart
              AdaptiveDropdown<bool?>(
                value: _emergencyFilter,
                decoration:
                    const InputDecoration(labelText: 'Emergency events'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All events')),
                  DropdownMenuItem(
                      value: true,
                      child: Text('Emergency only')),
                  DropdownMenuItem(
                      value: false,
                      child: Text('Non-emergency only')),
                ],
                onChanged: (v) =>
                    setLocal(() => _emergencyFilter = v),
              ),
```

- [ ] **Step 4: Verify**

```bash
flutter analyze --no-pub lib/presentation/reporting/screens/reporting_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/reporting/screens/reporting_screen.dart
git commit -m "feat(task7): migrate reporting_screen filter dropdowns to adaptive"
```

---

## Task 7: Migrate `patient_form_screen.dart` (generic helper + inline dropdown)

**Files:**
- Modify: `lib/presentation/patients/screens/patient_form_screen.dart`

Two targets:
1. `_dropdownRow<T>` helper (line 376) — a private generic method that wraps `DropdownButtonFormField<T>`. Replace the body to use `AdaptiveDropdown<T>`.
2. Inline `DropdownButtonFormField<String>` inside `_allergyRow` (line 412) — uses `isDense: true` in the decoration, which flows through `InputDecoration` unchanged.

- [ ] **Step 1: Migrate the `_dropdownRow<T>` helper (line 376)**

Find:

```dart
  Widget _dropdownRow<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label),
    );
  }
```

→

```dart
  Widget _dropdownRow<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return AdaptiveDropdown<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label),
    );
  }
```

- [ ] **Step 2: Migrate the inline dropdown in `_allergyRow` (line 412)**

Find:

```dart
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: allergy['severity'],
                decoration: const InputDecoration(
                    labelText: 'Severity', isDense: true),
                items: _severities
                    .map((s) => DropdownMenuItem(
                        value: s.$1, child: Text(s.$2)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => allergy['severity'] = v!),
              ),
            ),
```

→

```dart
            Expanded(
              flex: 2,
              child: AdaptiveDropdown<String>(
                value: allergy['severity'],
                decoration: const InputDecoration(
                    labelText: 'Severity', isDense: true),
                items: _severities
                    .map((s) => DropdownMenuItem(
                        value: s.$1, child: Text(s.$2)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => allergy['severity'] = v!),
              ),
            ),
```

- [ ] **Step 3: Verify**

```bash
flutter analyze --no-pub lib/presentation/patients/screens/patient_form_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/patients/screens/patient_form_screen.dart
git commit -m "feat(task7): migrate patient_form_screen dropdowns to adaptive"
```

---

## Task 8: Migrate `clinical_forms.dart` (5 dropdowns)

**Files:**
- Modify: `lib/presentation/patients/widgets/clinical_forms.dart`

Five dropdowns:
- Line 140: `initialValue: _type` → `value: _type` (AppointmentForm — Appointment Type)
- Line 320: `initialValue: _route` → `value: _route` (PrescriptionForm — Route)
- Line 507: `initialValue: _testType` → `value: _testType` (LabResultForm — Test Type, inside Row)
- Line 518: `initialValue: _priority` → `value: _priority` (LabResultForm — Priority, inside Row)
- Line 710: `initialValue: _documentType` → `value: _documentType` (MedicalDocumentForm — Document Type)

All use `initialValue:` — change to `value:` in `AdaptiveDropdown`. The backing `_type`, `_route`, `_testType`, `_priority`, `_documentType` variables are always set by `onChanged`, so `value:` is correct.

- [ ] **Step 1: Migrate AppointmentForm Type dropdown (line 140)**

Find:

```dart
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Appointment Type *'),
              items: _types
                  .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                  .toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
```

→

```dart
            AdaptiveDropdown<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Appointment Type *'),
              items: _types
                  .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                  .toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
```

- [ ] **Step 2: Migrate PrescriptionForm Route dropdown (line 320)**

Find:

```dart
            DropdownButtonFormField<String>(
              initialValue: _route,
              decoration: const InputDecoration(labelText: 'Route *'),
              items: _routes
                  .map((r) => DropdownMenuItem(value: r.$1, child: Text(r.$2)))
                  .toList(),
              onChanged: (v) => setState(() => _route = v!),
            ),
```

→

```dart
            AdaptiveDropdown<String>(
              value: _route,
              decoration: const InputDecoration(labelText: 'Route *'),
              items: _routes
                  .map((r) => DropdownMenuItem(value: r.$1, child: Text(r.$2)))
                  .toList(),
              onChanged: (v) => setState(() => _route = v!),
            ),
```

- [ ] **Step 3: Migrate LabResultForm Test Type + Priority dropdowns (lines 507, 518)**

Find:

```dart
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _testType,
                  decoration: const InputDecoration(labelText: 'Test Type *'),
                  items: _testTypes
                      .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                      .toList(),
                  onChanged: (v) => setState(() => _testType = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: _priorities
                      .map((p) => DropdownMenuItem(value: p.$1, child: Text(p.$2)))
                      .toList(),
                  onChanged: (v) => setState(() => _priority = v!),
                ),
              ),
            ]),
```

→

```dart
            Row(children: [
              Expanded(
                child: AdaptiveDropdown<String>(
                  value: _testType,
                  decoration: const InputDecoration(labelText: 'Test Type *'),
                  items: _testTypes
                      .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                      .toList(),
                  onChanged: (v) => setState(() => _testType = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AdaptiveDropdown<String>(
                  value: _priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: _priorities
                      .map((p) => DropdownMenuItem(value: p.$1, child: Text(p.$2)))
                      .toList(),
                  onChanged: (v) => setState(() => _priority = v!),
                ),
              ),
            ]),
```

- [ ] **Step 4: Migrate MedicalDocumentForm Document Type dropdown (line 710)**

Find:

```dart
            DropdownButtonFormField<String>(
              initialValue: _documentType,
              decoration: const InputDecoration(labelText: 'Document Type *'),
              items: _types
                  .map((t) =>
                      DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                  .toList(),
              onChanged: (v) => setState(() => _documentType = v!),
            ),
```

→

```dart
            AdaptiveDropdown<String>(
              value: _documentType,
              decoration: const InputDecoration(labelText: 'Document Type *'),
              items: _types
                  .map((t) =>
                      DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                  .toList(),
              onChanged: (v) => setState(() => _documentType = v!),
            ),
```

- [ ] **Step 5: Verify**

```bash
flutter analyze --no-pub lib/presentation/patients/widgets/clinical_forms.dart
```

Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/patients/widgets/clinical_forms.dart
git commit -m "feat(task7): migrate clinical_forms dropdowns to adaptive"
```

---

## Task 9: Migrate `clinical_record_forms.dart` (5 dropdowns)

**Files:**
- Modify: `lib/presentation/patients/widgets/clinical_record_forms.dart`

Five dropdowns:
- Line 359: `DiagnosisForm` — Diagnosis Type (`initialValue: _type`)
- Line 369: `DiagnosisForm` — Status (`initialValue: _status`)
- Line 459: `ProblemForm` — Status (`initialValue: _status`)
- Line 554: `ProcedureForm` — Status (`initialValue: _status`)
- Line 689: `ImmunizationForm` — Route (`initialValue: _route`)

All use `initialValue:` backed by state variables — change to `value:`.

- [ ] **Step 1: Migrate DiagnosisForm Diagnosis Type + Status dropdowns (lines 359, 369)**

Find:

```dart
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: _field('Diagnosis Type'),
                items: _types
                    .map((t) => DropdownMenuItem(
                        value: t.$1, child: Text(t.$2)))
                    .toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: _field('Status'),
                items: _statuses
                    .map((s) => DropdownMenuItem(
                        value: s.$1, child: Text(s.$2)))
                    .toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
```

→

```dart
              AdaptiveDropdown<String>(
                value: _type,
                decoration: _field('Diagnosis Type'),
                items: _types
                    .map((t) => DropdownMenuItem(
                        value: t.$1, child: Text(t.$2)))
                    .toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 12),
              AdaptiveDropdown<String>(
                value: _status,
                decoration: _field('Status'),
                items: _statuses
                    .map((s) => DropdownMenuItem(
                        value: s.$1, child: Text(s.$2)))
                    .toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
```

- [ ] **Step 2: Migrate ProblemForm Status dropdown (line 459)**

Find:

```dart
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: _field('Status'),
                items: _statuses
                    .map((s) => DropdownMenuItem(
                        value: s.$1, child: Text(s.$2)))
                    .toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
```

→

```dart
              AdaptiveDropdown<String>(
                value: _status,
                decoration: _field('Status'),
                items: _statuses
                    .map((s) => DropdownMenuItem(
                        value: s.$1, child: Text(s.$2)))
                    .toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
```

- [ ] **Step 3: Migrate ProcedureForm Status dropdown (line 554)**

Find:

```dart
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: _field('Status'),
                items: _statuses
                    .map((s) => DropdownMenuItem(
                        value: s.$1, child: Text(s.$2)))
                    .toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
```

→

```dart
              AdaptiveDropdown<String>(
                value: _status,
                decoration: _field('Status'),
                items: _statuses
                    .map((s) => DropdownMenuItem(
                        value: s.$1, child: Text(s.$2)))
                    .toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
```

- [ ] **Step 4: Migrate ImmunizationForm Route dropdown (line 689)**

Find:

```dart
              DropdownButtonFormField<String>(
                initialValue: _route,
                decoration: _field('Route'),
                items: _routes
                    .map((r) => DropdownMenuItem(
                        value: r.$1, child: Text(r.$2)))
                    .toList(),
                onChanged: (v) => setState(() => _route = v!),
              ),
```

→

```dart
              AdaptiveDropdown<String>(
                value: _route,
                decoration: _field('Route'),
                items: _routes
                    .map((r) => DropdownMenuItem(
                        value: r.$1, child: Text(r.$2)))
                    .toList(),
                onChanged: (v) => setState(() => _route = v!),
              ),
```

- [ ] **Step 5: Verify**

```bash
flutter analyze --no-pub lib/presentation/patients/widgets/clinical_record_forms.dart
```

Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/patients/widgets/clinical_record_forms.dart
git commit -m "feat(task7): migrate clinical_record_forms dropdowns to adaptive"
```

---

## Final: Full-project analysis

- [ ] **Step 1: Run full analyzer**

```bash
flutter analyze --no-pub
```

Expected: `No issues found!`

- [ ] **Step 2: Confirm dropdown count**

```bash
grep -rn "DropdownButtonFormField" lib/presentation/
```

Expected: 0 results — all call sites migrated.

- [ ] **Step 3: Verify AdaptiveDropdown exists in platform.dart**

```bash
grep -n "class AdaptiveDropdown" lib/core/platform.dart
```

Expected: one match.
