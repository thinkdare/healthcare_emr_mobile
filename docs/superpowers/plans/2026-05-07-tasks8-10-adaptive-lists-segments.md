# Tasks 8–10: Adaptive Lists, Segmented Control, Small Widgets — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the iOS platform-adaptive sprint by replacing Material list tiles with Cupertino equivalents + swipe-to-delete in the clinical record tab, replacing the patient detail `TabBar`/`TabBarView` with `CupertinoSlidingSegmentedControl`/`IndexedStack`, and adding `CupertinoSearchTextField` + adaptive activity indicators.

**Architecture:** All changes follow the established `kIsIOS` branching pattern already used throughout the app. No new files are created — all changes are confined to three existing presentation files plus `clinical_record_tab.dart`. Android paths are preserved verbatim in every `else` branch.

**Tech Stack:** Flutter 3.41, `package:flutter/cupertino.dart` (already imported via `platform.dart`), existing `Provider` state management, `AppColors` from `lib/config/app_colors.dart`.

---

## File Map

| File | Task | Changes |
|------|------|---------|
| `lib/presentation/patients/widgets/clinical_record_tab.dart` | 8 | Loading indicator → adaptive; RefreshIndicator → CupertinoSliverRefreshControl on iOS; 5 ListTile classes → CupertinoListTile + Dismissible on iOS |
| `lib/presentation/patients/screens/patient_detail_screen.dart` | 9 | Add `_iosSegment` state; iOS build branch with CupertinoSlidingSegmentedControl + IndexedStack; FAB → nav bar trailing; clinical form picker → CupertinoActionSheet on iOS |
| `lib/presentation/patients/screens/patient_list_screen.dart` | 10 | Add CupertinoSearchTextField for iOS search; CircularProgressIndicator → adaptive |

---

## Task 8: `clinical_record_tab.dart` — adaptive lists

**Files:**
- Modify: `lib/presentation/patients/widgets/clinical_record_tab.dart`

Current state:
- `ClinicalRecordTab.build()` returns `RefreshIndicator` wrapping `ListView`
- Loading state returns `Center(child: CircularProgressIndicator())`
- 5 tile classes (`_VitalSignTile`, `_DiagnosisTile`, `_ProblemTile`, `_ProcedureTile`, `_ImmunizationTile`) each return `ListTile` with a trailing delete `IconButton`

Changes:
- Add `import '../../../config/app_colors.dart';` (needed for `AppColors.error` in Dismissible background)
- Add `import 'package:flutter/cupertino.dart';` (for `CupertinoActivityIndicator`, `CupertinoListTile`, etc. — already available via `platform.dart` but needed for direct class references)
- Loading state: `kIsIOS ? CupertinoActivityIndicator() : CircularProgressIndicator()`
- `ClinicalRecordTab.build()` iOS path: `CustomScrollView` with `CupertinoSliverRefreshControl` + `SliverList`
- Each tile: iOS returns `Dismissible` wrapping `CupertinoListTile` (no delete icon); Android returns existing `ListTile` unchanged

- [ ] **Step 1: Add missing imports to `clinical_record_tab.dart`**

At the top of the file, the imports currently are:
```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/platform.dart';
import '../../../data/models/clinical_record_models.dart';
import '../../../data/providers/clinical_provider.dart';
import 'clinical_record_forms.dart';
```

Replace with:
```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../config/app_colors.dart';
import '../../../core/platform.dart';
import '../../../data/models/clinical_record_models.dart';
import '../../../data/providers/clinical_provider.dart';
import 'clinical_record_forms.dart';
```

- [ ] **Step 2: Update `ClinicalRecordTab.build()` — loading indicator + iOS refresh**

Find (lines 20–58):
```dart
  @override
  Widget build(BuildContext context) {
    return Consumer<ClinicalProvider>(
      builder: (context, clinical, _) {
        if (clinical.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (clinical.error != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(clinical.error!,
                    style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
                AdaptiveFilledButton(
                  onPressed: () =>
                      clinical.loadAll(clinical.patientId!),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => clinical.loadAll(clinical.patientId!),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _VitalSignsSection(clinical.vitalSigns),
              _DiagnosesSection(clinical.diagnoses),
              _ProblemsSection(clinical.problems),
              _ProceduresSection(clinical.procedures),
              _ImmunizationsSection(clinical.immunizations),
            ],
          ),
        );
      },
    );
  }
```

→

```dart
  @override
  Widget build(BuildContext context) {
    return Consumer<ClinicalProvider>(
      builder: (context, clinical, _) {
        if (clinical.isLoading) {
          return const Center(
            child: kIsIOS
                ? CupertinoActivityIndicator()
                : CircularProgressIndicator(),
          );
        }
        if (clinical.error != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(clinical.error!,
                    style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
                AdaptiveFilledButton(
                  onPressed: () =>
                      clinical.loadAll(clinical.patientId!),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final sections = [
          _VitalSignsSection(clinical.vitalSigns),
          _DiagnosesSection(clinical.diagnoses),
          _ProblemsSection(clinical.problems),
          _ProceduresSection(clinical.procedures),
          _ImmunizationsSection(clinical.immunizations),
        ];

        if (kIsIOS) {
          return CustomScrollView(
            slivers: [
              CupertinoSliverRefreshControl(
                onRefresh: () => clinical.loadAll(clinical.patientId!),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                sliver: SliverList.list(children: sections),
              ),
            ],
          );
        }

        return RefreshIndicator(
          onRefresh: () => clinical.loadAll(clinical.patientId!),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: sections,
          ),
        );
      },
    );
  }
```

- [ ] **Step 3: Replace `_VitalSignTile` with adaptive Dismissible + CupertinoListTile**

Find (lines 154–184):
```dart
class _VitalSignTile extends StatelessWidget {
  final VitalSignModel v;
  const _VitalSignTile(this.v);

  @override
  Widget build(BuildContext context) {
    final date =
        DateFormat('dd MMM yyyy HH:mm').format(v.recordedAt.toLocal());
    return ListTile(
      dense: true,
      title:
          Text(date, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Wrap(
        spacing: 12,
        children: [
          if (v.bloodPressureSystolic != null)
            Text('BP: ${v.bpDisplay}'),
          if (v.heartRate != null) Text('HR: ${v.heartRate} bpm'),
          if (v.oxygenSaturation != null) Text('SpO₂: ${v.spo2Display}'),
          if (v.temperature != null) Text('Temp: ${v.tempDisplay}'),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.red),
        onPressed: () => _confirmDelete(context, 'vital sign reading', () {
          context.read<ClinicalProvider>().deleteVitalSign(v.id);
        }),
      ),
    );
  }
}
```

→

```dart
class _VitalSignTile extends StatelessWidget {
  final VitalSignModel v;
  const _VitalSignTile(this.v);

  @override
  Widget build(BuildContext context) {
    final date =
        DateFormat('dd MMM yyyy HH:mm').format(v.recordedAt.toLocal());
    final subtitle = Wrap(
      spacing: 12,
      children: [
        if (v.bloodPressureSystolic != null) Text('BP: ${v.bpDisplay}'),
        if (v.heartRate != null) Text('HR: ${v.heartRate} bpm'),
        if (v.oxygenSaturation != null) Text('SpO₂: ${v.spo2Display}'),
        if (v.temperature != null) Text('Temp: ${v.tempDisplay}'),
      ],
    );

    if (kIsIOS) {
      return Dismissible(
        key: ValueKey(v.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          bool confirmed = false;
          await _confirmDelete(
              context, 'vital sign reading', () => confirmed = true);
          return confirmed;
        },
        onDismissed: (_) =>
            context.read<ClinicalProvider>().deleteVitalSign(v.id),
        background: Container(
          color: AppColors.error,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(CupertinoIcons.delete,
              color: CupertinoColors.white),
        ),
        child: CupertinoListTile(
          title: Text(date,
              style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: subtitle,
        ),
      );
    }

    return ListTile(
      dense: true,
      title: Text(date,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle,
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.red),
        onPressed: () =>
            _confirmDelete(context, 'vital sign reading', () {
          context.read<ClinicalProvider>().deleteVitalSign(v.id);
        }),
      ),
    );
  }
}
```

- [ ] **Step 4: Replace `_DiagnosisTile` with adaptive variant**

Find (lines 203–248):
```dart
class _DiagnosisTile extends StatelessWidget {
  final DiagnosisModel d;
  const _DiagnosisTile(this.d);

  Color get _statusColor => switch (d.status) {
        'active'       => Colors.red,
        'in_remission' => Colors.orange,
        'resolved'     => Colors.green,
        _              => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(d.description,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Row(children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            d.status,
            style: TextStyle(color: _statusColor, fontSize: 11),
          ),
        ),
        if (d.icdCode != null) ...[
          const SizedBox(width: 8),
          Text(d.icdCode!,
              style:
                  const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ]),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.red),
        onPressed: () => _confirmDelete(context, 'diagnosis', () {
          context.read<ClinicalProvider>().deleteDiagnosis(d.id);
        }),
      ),
    );
  }
}
```

→

```dart
class _DiagnosisTile extends StatelessWidget {
  final DiagnosisModel d;
  const _DiagnosisTile(this.d);

  Color get _statusColor => switch (d.status) {
        'active'       => Colors.red,
        'in_remission' => Colors.orange,
        'resolved'     => Colors.green,
        _              => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    final subtitle = Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: _statusColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(d.status,
            style: TextStyle(color: _statusColor, fontSize: 11)),
      ),
      if (d.icdCode != null) ...[
        const SizedBox(width: 8),
        Text(d.icdCode!,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    ]);

    if (kIsIOS) {
      return Dismissible(
        key: ValueKey(d.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          bool confirmed = false;
          await _confirmDelete(
              context, 'diagnosis', () => confirmed = true);
          return confirmed;
        },
        onDismissed: (_) =>
            context.read<ClinicalProvider>().deleteDiagnosis(d.id),
        background: Container(
          color: AppColors.error,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(CupertinoIcons.delete,
              color: CupertinoColors.white),
        ),
        child: CupertinoListTile(
          title: Text(d.description,
              style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: subtitle,
        ),
      );
    }

    return ListTile(
      dense: true,
      title: Text(d.description,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle,
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.red),
        onPressed: () => _confirmDelete(context, 'diagnosis', () {
          context.read<ClinicalProvider>().deleteDiagnosis(d.id);
        }),
      ),
    );
  }
}
```

- [ ] **Step 5: Replace `_ProblemTile` with adaptive variant**

Find (lines 267–292):
```dart
class _ProblemTile extends StatelessWidget {
  final ProblemListModel p;
  const _ProblemTile(this.p);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(p.description,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        p.status,
        style: TextStyle(
          color: p.isActive ? Colors.orange : Colors.green,
          fontSize: 11,
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.red),
        onPressed: () => _confirmDelete(context, 'problem', () {
          context.read<ClinicalProvider>().deleteProblem(p.id);
        }),
      ),
    );
  }
}
```

→

```dart
class _ProblemTile extends StatelessWidget {
  final ProblemListModel p;
  const _ProblemTile(this.p);

  @override
  Widget build(BuildContext context) {
    final subtitle = Text(
      p.status,
      style: TextStyle(
        color: p.isActive ? Colors.orange : Colors.green,
        fontSize: 11,
      ),
    );

    if (kIsIOS) {
      return Dismissible(
        key: ValueKey(p.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          bool confirmed = false;
          await _confirmDelete(
              context, 'problem', () => confirmed = true);
          return confirmed;
        },
        onDismissed: (_) =>
            context.read<ClinicalProvider>().deleteProblem(p.id),
        background: Container(
          color: AppColors.error,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(CupertinoIcons.delete,
              color: CupertinoColors.white),
        ),
        child: CupertinoListTile(
          title: Text(p.description,
              style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: subtitle,
        ),
      );
    }

    return ListTile(
      dense: true,
      title: Text(p.description,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle,
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.red),
        onPressed: () => _confirmDelete(context, 'problem', () {
          context.read<ClinicalProvider>().deleteProblem(p.id);
        }),
      ),
    );
  }
}
```

- [ ] **Step 6: Replace `_ProcedureTile` with adaptive variant**

Find (lines 311–336):
```dart
class _ProcedureTile extends StatelessWidget {
  final ProcedureModel p;
  const _ProcedureTile(this.p);

  @override
  Widget build(BuildContext context) {
    final date = p.performedAt != null
        ? DateFormat('dd MMM yyyy').format(p.performedAt!.toLocal())
        : 'Date unknown';
    return ListTile(
      dense: true,
      title: Text(p.description,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        '$date · ${p.status}',
        style: const TextStyle(fontSize: 11),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.red),
        onPressed: () => _confirmDelete(context, 'procedure', () {
          context.read<ClinicalProvider>().deleteProcedure(p.id);
        }),
      ),
    );
  }
}
```

→

```dart
class _ProcedureTile extends StatelessWidget {
  final ProcedureModel p;
  const _ProcedureTile(this.p);

  @override
  Widget build(BuildContext context) {
    final date = p.performedAt != null
        ? DateFormat('dd MMM yyyy').format(p.performedAt!.toLocal())
        : 'Date unknown';
    final subtitle = Text('$date · ${p.status}',
        style: const TextStyle(fontSize: 11));

    if (kIsIOS) {
      return Dismissible(
        key: ValueKey(p.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          bool confirmed = false;
          await _confirmDelete(
              context, 'procedure', () => confirmed = true);
          return confirmed;
        },
        onDismissed: (_) =>
            context.read<ClinicalProvider>().deleteProcedure(p.id),
        background: Container(
          color: AppColors.error,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(CupertinoIcons.delete,
              color: CupertinoColors.white),
        ),
        child: CupertinoListTile(
          title: Text(p.description,
              style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: subtitle,
        ),
      );
    }

    return ListTile(
      dense: true,
      title: Text(p.description,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle,
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.red),
        onPressed: () => _confirmDelete(context, 'procedure', () {
          context.read<ClinicalProvider>().deleteProcedure(p.id);
        }),
      ),
    );
  }
}
```

- [ ] **Step 7: Replace `_ImmunizationTile` with adaptive variant**

Find (lines 355–380):
```dart
class _ImmunizationTile extends StatelessWidget {
  final ImmunizationModel i;
  const _ImmunizationTile(this.i);

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd MMM yyyy')
        .format(i.administeredAt.toLocal());
    return ListTile(
      dense: true,
      title: Text(i.vaccineName,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        '$date · ${i.doseDisplay} · ${i.route}',
        style: const TextStyle(fontSize: 11),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.red),
        onPressed: () =>
            _confirmDelete(context, 'immunization record', () {
          context.read<ClinicalProvider>().deleteImmunization(i.id);
        }),
      ),
    );
  }
}
```

→

```dart
class _ImmunizationTile extends StatelessWidget {
  final ImmunizationModel i;
  const _ImmunizationTile(this.i);

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd MMM yyyy')
        .format(i.administeredAt.toLocal());
    final subtitle = Text('$date · ${i.doseDisplay} · ${i.route}',
        style: const TextStyle(fontSize: 11));

    if (kIsIOS) {
      return Dismissible(
        key: ValueKey(i.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          bool confirmed = false;
          await _confirmDelete(
              context, 'immunization record', () => confirmed = true);
          return confirmed;
        },
        onDismissed: (_) =>
            context.read<ClinicalProvider>().deleteImmunization(i.id),
        background: Container(
          color: AppColors.error,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(CupertinoIcons.delete,
              color: CupertinoColors.white),
        ),
        child: CupertinoListTile(
          title: Text(i.vaccineName,
              style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: subtitle,
        ),
      );
    }

    return ListTile(
      dense: true,
      title: Text(i.vaccineName,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle,
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.red),
        onPressed: () =>
            _confirmDelete(context, 'immunization record', () {
          context.read<ClinicalProvider>().deleteImmunization(i.id);
        }),
      ),
    );
  }
}
```

- [ ] **Step 8: Verify**

```bash
cd /home/dh/Forge/sandbox/healthcare_emr_mobile
flutter analyze --no-pub lib/presentation/patients/widgets/clinical_record_tab.dart
```

Expected: `No issues found!`

- [ ] **Step 9: Commit**

```bash
git add lib/presentation/patients/widgets/clinical_record_tab.dart
git commit -m "feat(task8): adaptive lists in clinical_record_tab — CupertinoListTile, Dismissible, CupertinoSliverRefreshControl"
```

---

## Task 9: `patient_detail_screen.dart` — segmented control

**Files:**
- Modify: `lib/presentation/patients/screens/patient_detail_screen.dart`

Current state:
- `_PatientDetailScreenState` has `TabController _tabs` and `int _currentTab`
- `build()` returns a single `Scaffold` with `appBar` that already branches on `kIsIOS` (nav bar set in Task 4)
- `TabBar` is embedded inside `AppBar.bottom` (Android only — the iOS nav bar has no `bottom`)
- `body` is `Consumer<ClinicalProvider>` that returns `TabBarView` on both platforms
- FAB shows on `_currentTab 1–4`
- `_showClinicalRecordFormPicker()` uses `showModalBottomSheet` with `ListTile` items

Changes:
- Add `int _iosSegment = 0;` to state
- Add iOS build path: `CupertinoPageScaffold` + nav bar with `+` button + `CupertinoSlidingSegmentedControl` + `IndexedStack`
- Update `_openClinicalForm()` to read `_visibleIndices[_iosSegment]` on iOS
- Replace `_showClinicalRecordFormPicker()` with `CupertinoActionSheet` on iOS

- [ ] **Step 1: Add `_iosSegment` state variable**

In `_PatientDetailScreenState`, find:
```dart
  int _currentTab = 0;
  late List<int> _visibleIndices;
```

→

```dart
  int _currentTab = 0;
  int _iosSegment = 0;
  late List<int> _visibleIndices;
```

- [ ] **Step 2: Update `_openClinicalForm()` to support iOS segment index**

Find the first line of `_openClinicalForm()`:
```dart
  Future<void> _openClinicalForm() async {
    final auth = context.read<AuthProvider>();
    Widget? form;

    switch (_currentTab) {
```

→

```dart
  Future<void> _openClinicalForm() async {
    final auth = context.read<AuthProvider>();
    Widget? form;
    final tabIndex = kIsIOS ? _visibleIndices[_iosSegment] : _currentTab;

    switch (tabIndex) {
```

Then find every remaining `_currentTab` reference inside `_openClinicalForm()`. There is one in the reload block at the end:
```dart
    if (created == true && mounted) {
      final clinical = context.read<ClinicalProvider>();
      switch (_currentTab) {
```

→

```dart
    if (created == true && mounted) {
      final clinical = context.read<ClinicalProvider>();
      switch (tabIndex) {
```

- [ ] **Step 3: Update `_showClinicalRecordFormPicker()` — CupertinoActionSheet on iOS**

Find (lines 133–190):
```dart
  Future<void> _showClinicalRecordFormPicker() async {
    final formType = await showModalBottomSheet<Type>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.monitor_heart),
              title: const Text('Vital Signs'),
              onTap: () => Navigator.pop(ctx, VitalSignForm),
            ),
            ListTile(
              leading: const Icon(Icons.medical_information),
              title: const Text('Diagnosis'),
              onTap: () => Navigator.pop(ctx, DiagnosisForm),
            ),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('Problem'),
              onTap: () => Navigator.pop(ctx, ProblemForm),
            ),
            ListTile(
              leading: const Icon(Icons.local_hospital),
              title: const Text('Procedure'),
              onTap: () => Navigator.pop(ctx, ProcedureForm),
            ),
            ListTile(
              leading: const Icon(Icons.vaccines),
              title: const Text('Immunization'),
              onTap: () => Navigator.pop(ctx, ImmunizationForm),
            ),
          ],
        ),
      ),
    );
```

→

```dart
  Future<void> _showClinicalRecordFormPicker() async {
    Type? formType;

    if (kIsIOS) {
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: const Text('Add Clinical Record'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                formType = VitalSignForm;
                Navigator.of(ctx).pop();
              },
              child: const Text('Vital Signs'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                formType = DiagnosisForm;
                Navigator.of(ctx).pop();
              },
              child: const Text('Diagnosis'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                formType = ProblemForm;
                Navigator.of(ctx).pop();
              },
              child: const Text('Problem'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                formType = ProcedureForm;
                Navigator.of(ctx).pop();
              },
              child: const Text('Procedure'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                formType = ImmunizationForm;
                Navigator.of(ctx).pop();
              },
              child: const Text('Immunization'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ),
      );
    } else {
      formType = await showModalBottomSheet<Type>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.monitor_heart),
                title: const Text('Vital Signs'),
                onTap: () => Navigator.pop(ctx, VitalSignForm),
              ),
              ListTile(
                leading: const Icon(Icons.medical_information),
                title: const Text('Diagnosis'),
                onTap: () => Navigator.pop(ctx, DiagnosisForm),
              ),
              ListTile(
                leading: const Icon(Icons.list_alt),
                title: const Text('Problem'),
                onTap: () => Navigator.pop(ctx, ProblemForm),
              ),
              ListTile(
                leading: const Icon(Icons.local_hospital),
                title: const Text('Procedure'),
                onTap: () => Navigator.pop(ctx, ProcedureForm),
              ),
              ListTile(
                leading: const Icon(Icons.vaccines),
                title: const Text('Immunization'),
                onTap: () => Navigator.pop(ctx, ImmunizationForm),
              ),
            ],
          ),
        ),
      );
    }
```

- [ ] **Step 4: Add iOS build path to `build()` — CupertinoPageScaffold + segmented control**

The current `build()` method (lines 214–311) returns a single `Scaffold`. The `Scaffold.appBar` already branches on `kIsIOS` to show a `CupertinoNavigationBar`. We need to replace the whole `build()` with a version that uses `CupertinoPageScaffold` on iOS.

Find (lines 214–311):
```dart
  @override
  Widget build(BuildContext context) {
    final p = _patient;
    final auth = context.read<AuthProvider>();
    final canEdit = auth.staffType == 'doctor' || auth.staffType == 'admin' ||
        auth.staffType == 'nurse';
    return Scaffold(
      floatingActionButton: _currentTab >= 1 && _currentTab <= 4
          ? FloatingActionButton(
              onPressed: _openClinicalForm,
              tooltip: switch (_currentTab) {
                1 => 'Book Appointment',
                2 => auth.staffType == 'pharmacist'
                    ? 'Fill Prescription'
                    : 'New Prescription',
                3 => auth.staffType == 'lab_technician' ||
                        auth.staffType == 'lab_tech'
                    ? 'Record Results'
                    : 'Order Lab Test',
                4 => 'Upload Document',
                _ => 'Add',
              },
              child: Icon(_currentTab == 4 ? Icons.upload_file : Icons.add),
            )
          : null,
      appBar: kIsIOS
          ? CupertinoNavigationBar(
              middle: Text(p.fullName),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canEdit)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _openEdit,
                      child: const Icon(CupertinoIcons.pencil),
                    ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () =>
                        context.read<ClinicalProvider>().loadAll(p.id),
                    child: const Icon(CupertinoIcons.refresh),
                  ),
                ],
              ),
            )
          : AppBar(
              title: Text(p.fullName),
              actions: [
                if (canEdit)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit patient',
                    onPressed: _openEdit,
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: () =>
                      context.read<ClinicalProvider>().loadAll(p.id),
                ),
              ],
              bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: [
            for (final i in _visibleIndices)
              Tab(text: const ['Overview', 'Appointments', 'Prescriptions',
                  'Lab Results', 'Documents', 'Clinical Record'][i]),
          ],
        ),
      ),
      body: Consumer<ClinicalProvider>(
        builder: (context, clinical, _) {
          if (clinical.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (clinical.error != null) {
            return _ErrorView(
              message: clinical.error!,
              onRetry: () => clinical.loadAll(p.id),
            );
          }
          final allTabViews = [
            _OverviewTab(patient: _patient),
            _AppointmentsTab(patientId: _patient.id),
            _PrescriptionsTab(patientId: _patient.id),
            _LabResultsTab(patientId: _patient.id),
            _DocumentsTab(patientId: _patient.id),
            const ClinicalRecordTab(),
          ];
          return TabBarView(
            controller: _tabs,
            children: [for (final i in _visibleIndices) allTabViews[i]],
          );
        },
      ),
    );
  }
```

→

```dart
  @override
  Widget build(BuildContext context) {
    final p = _patient;
    final auth = context.read<AuthProvider>();
    final canEdit = auth.staffType == 'doctor' || auth.staffType == 'admin' ||
        auth.staffType == 'nurse';

    if (kIsIOS) {
      final iosTabIndex = _visibleIndices[_iosSegment];
      final showAdd = iosTabIndex >= 1;
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(p.fullName),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showAdd)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _openClinicalForm,
                  child: const Icon(CupertinoIcons.add),
                ),
              if (canEdit)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _openEdit,
                  child: const Icon(CupertinoIcons.pencil),
                ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () =>
                    context.read<ClinicalProvider>().loadAll(p.id),
                child: const Icon(CupertinoIcons.refresh),
              ),
            ],
          ),
        ),
        child: SafeArea(
          child: Consumer<ClinicalProvider>(
            builder: (context, clinical, _) {
              if (clinical.isLoading) {
                return const Center(child: CupertinoActivityIndicator());
              }
              if (clinical.error != null) {
                return _ErrorView(
                  message: clinical.error!,
                  onRetry: () => clinical.loadAll(p.id),
                );
              }
              final allTabViews = [
                _OverviewTab(patient: _patient),
                _AppointmentsTab(patientId: _patient.id),
                _PrescriptionsTab(patientId: _patient.id),
                _LabResultsTab(patientId: _patient.id),
                _DocumentsTab(patientId: _patient.id),
                const ClinicalRecordTab(),
              ];
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: CupertinoSlidingSegmentedControl<int>(
                      groupValue: _iosSegment,
                      onValueChanged: (v) =>
                          setState(() => _iosSegment = v ?? 0),
                      children: {
                        for (int i = 0; i < _visibleIndices.length; i++)
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
                        for (final i in _visibleIndices) allTabViews[i],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }

    // Android path
    return Scaffold(
      floatingActionButton: _currentTab >= 1 && _currentTab <= 4
          ? FloatingActionButton(
              onPressed: _openClinicalForm,
              tooltip: switch (_currentTab) {
                1 => 'Book Appointment',
                2 => auth.staffType == 'pharmacist'
                    ? 'Fill Prescription'
                    : 'New Prescription',
                3 => auth.staffType == 'lab_technician' ||
                        auth.staffType == 'lab_tech'
                    ? 'Record Results'
                    : 'Order Lab Test',
                4 => 'Upload Document',
                _ => 'Add',
              },
              child: Icon(_currentTab == 4 ? Icons.upload_file : Icons.add),
            )
          : null,
      appBar: AppBar(
        title: Text(p.fullName),
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit patient',
              onPressed: _openEdit,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () =>
                context.read<ClinicalProvider>().loadAll(p.id),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: [
            for (final i in _visibleIndices)
              Tab(
                  text: const [
                'Overview',
                'Appointments',
                'Prescriptions',
                'Lab Results',
                'Documents',
                'Clinical Record'
              ][i]),
          ],
        ),
      ),
      body: Consumer<ClinicalProvider>(
        builder: (context, clinical, _) {
          if (clinical.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (clinical.error != null) {
            return _ErrorView(
              message: clinical.error!,
              onRetry: () => clinical.loadAll(p.id),
            );
          }
          final allTabViews = [
            _OverviewTab(patient: _patient),
            _AppointmentsTab(patientId: _patient.id),
            _PrescriptionsTab(patientId: _patient.id),
            _LabResultsTab(patientId: _patient.id),
            _DocumentsTab(patientId: _patient.id),
            const ClinicalRecordTab(),
          ];
          return TabBarView(
            controller: _tabs,
            children: [for (final i in _visibleIndices) allTabViews[i]],
          );
        },
      ),
    );
  }
```

- [ ] **Step 5: Verify**

```bash
flutter analyze --no-pub lib/presentation/patients/screens/patient_detail_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/patients/screens/patient_detail_screen.dart
git commit -m "feat(task9): CupertinoSlidingSegmentedControl + IndexedStack in PatientDetailScreen on iOS"
```

---

## Task 10: `patient_list_screen.dart` — search field + adaptive indicators

**Files:**
- Modify: `lib/presentation/patients/screens/patient_list_screen.dart`

Current state:
- iOS nav bar already has a search toggle button (`_showSearchBar` state)
- When `_showSearchBar` is true on Android, `AppBar.title` switches to a `TextField`
- On iOS, the `AppBar` is replaced by `CupertinoNavigationBar` — so the search field is never shown on iOS
- 3 `CircularProgressIndicator` usages in the body (initial load, searching, load-more)

Changes:
- Add a `CupertinoSearchTextField` that appears below the nav bar in the iOS `Scaffold.body` when `_showSearchBar` is true
- Replace the 3 main `CircularProgressIndicator` usages with adaptive indicators

- [ ] **Step 1: Add iOS `CupertinoSearchTextField` to the body Column**

Find (lines 146–202):
```dart
          return Column(
            children: [
              // ── Offline/cache indicator ────────────────────────────────────
              if (fromCache && !isLoading)
                _CacheBanner(
                  lastRefreshed: stats.lastRefreshed,
                  onRefresh: _onRefresh,
                ),

              // ── Error banner ───────────────────────────────────────────────
              if (error != null)
                _ErrorBanner(
                  message: error,
                  onDismiss: () => patientProvider.clearError(),
                ),

              // ── Body ───────────────────────────────────────────────────────
              Expanded(
                child: isLoading && patients.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : isSearching
                        ? const Center(child: CircularProgressIndicator())
                        : patients.isEmpty
                            ? _EmptyState(
                                isSearching: _showSearchBar &&
                                    _searchController.text.isNotEmpty,
                                searchQuery: _searchController.text,
                              )
                            : RefreshIndicator(
                                onRefresh: _onRefresh,
                                child: ListView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8),
                                  itemCount: patients.length +
                                      (patientProvider.isLoadingMore
                                          ? 1
                                          : 0),
                                  itemBuilder: (_, index) {
                                    if (index == patients.length) {
                                      return const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Center(
                                            child:
                                                CircularProgressIndicator()),
                                      );
                                    }
                                    return PatientCard(
                                      patient: patients[index],
                                    );
                                  },
                                ),
                              ),
              ),
            ],
          );
```

→

```dart
          return Column(
            children: [
              // ── iOS search field ───────────────────────────────────────────
              if (kIsIOS && _showSearchBar)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: CupertinoSearchTextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    placeholder: 'Search by name, MRN, phone or email…',
                  ),
                ),

              // ── Offline/cache indicator ────────────────────────────────────
              if (fromCache && !isLoading)
                _CacheBanner(
                  lastRefreshed: stats.lastRefreshed,
                  onRefresh: _onRefresh,
                ),

              // ── Error banner ───────────────────────────────────────────────
              if (error != null)
                _ErrorBanner(
                  message: error,
                  onDismiss: () => patientProvider.clearError(),
                ),

              // ── Body ───────────────────────────────────────────────────────
              Expanded(
                child: isLoading && patients.isEmpty
                    ? const Center(
                        child: kIsIOS
                            ? CupertinoActivityIndicator()
                            : CircularProgressIndicator(),
                      )
                    : isSearching
                        ? const Center(
                            child: kIsIOS
                                ? CupertinoActivityIndicator()
                                : CircularProgressIndicator(),
                          )
                        : patients.isEmpty
                            ? _EmptyState(
                                isSearching: _showSearchBar &&
                                    _searchController.text.isNotEmpty,
                                searchQuery: _searchController.text,
                              )
                            : RefreshIndicator(
                                onRefresh: _onRefresh,
                                child: ListView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8),
                                  itemCount: patients.length +
                                      (patientProvider.isLoadingMore
                                          ? 1
                                          : 0),
                                  itemBuilder: (_, index) {
                                    if (index == patients.length) {
                                      return const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Center(
                                          child: kIsIOS
                                              ? CupertinoActivityIndicator()
                                              : CircularProgressIndicator(),
                                        ),
                                      );
                                    }
                                    return PatientCard(
                                      patient: patients[index],
                                    );
                                  },
                                ),
                              ),
              ),
            ],
          );
```

- [ ] **Step 2: Verify**

```bash
flutter analyze --no-pub lib/presentation/patients/screens/patient_list_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/presentation/patients/screens/patient_list_screen.dart
git commit -m "feat(task10): CupertinoSearchTextField + adaptive activity indicators in PatientListScreen"
```

---

## Final: Full-project analysis

- [ ] **Step 1: Full analyze**

```bash
flutter analyze --no-pub 2>&1
```

Expected: same 21 pre-existing issues as before, 0 new issues.

- [ ] **Step 2: Confirm no remaining unmitigated ListTile in clinical_record_tab**

```bash
grep -n "ListTile" lib/presentation/patients/widgets/clinical_record_tab.dart
```

Expected: 0 results (all replaced with Dismissible/CupertinoListTile on iOS + ListTile on Android).

- [ ] **Step 3: Confirm CupertinoSlidingSegmentedControl in patient_detail_screen**

```bash
grep -n "CupertinoSlidingSegmentedControl" lib/presentation/patients/screens/patient_detail_screen.dart
```

Expected: 1 result.
