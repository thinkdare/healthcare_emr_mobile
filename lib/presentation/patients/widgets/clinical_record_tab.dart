// lib/presentation/patients/widgets/clinical_record_tab.dart
//
// ClinicalRecordTab — Patient detail tab 5.
//
// Shows five collapsible sections (one per new clinical resource).
// Each section header has a "+" icon that opens the matching write form.
// Individual records show a delete icon with a confirmation dialog.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/platform.dart';
import '../../../data/models/clinical_record_models.dart';
import '../../../data/providers/clinical_provider.dart';
import 'clinical_record_forms.dart';

class ClinicalRecordTab extends StatelessWidget {
  const ClinicalRecordTab({super.key});

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
}

// ── Shared section scaffold ───────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final int count;
  final Widget form;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.count,
    required this.form,
    required this.children,
  });

  Future<void> _openForm(BuildContext context) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => form,
    );
    if (created == true && context.mounted) {
      context.read<ClinicalProvider>().loadAll(
            context.read<ClinicalProvider>().patientId!,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ExpansionTile(
        title: Text(
          '$title ($count)',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => _openForm(context),
              tooltip: 'Add',
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        children: children.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'None recorded',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              ]
            : children,
      ),
    );
  }
}

Future<void> _confirmDelete(
    BuildContext context, String label, VoidCallback onConfirm) {
  return showAdaptiveActionSheet(
    context: context,
    title: 'Delete Record',
    message: 'Delete this $label? This cannot be undone.',
    destructiveLabel: 'Delete',
    onConfirm: onConfirm,
  );
}

// ── Vital Signs ───────────────────────────────────────────────────────────────

class _VitalSignsSection extends StatelessWidget {
  final List<VitalSignModel> items;
  const _VitalSignsSection(this.items);

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Vital Signs',
      count: items.length,
      form: const VitalSignForm(),
      children: items.map((v) => _VitalSignTile(v)).toList(),
    );
  }
}

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

// ── Diagnoses ─────────────────────────────────────────────────────────────────

class _DiagnosesSection extends StatelessWidget {
  final List<DiagnosisModel> items;
  const _DiagnosesSection(this.items);

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Diagnoses',
      count: items.length,
      form: const DiagnosisForm(),
      children: items.map((d) => _DiagnosisTile(d)).toList(),
    );
  }
}

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

// ── Problem List ──────────────────────────────────────────────────────────────

class _ProblemsSection extends StatelessWidget {
  final List<ProblemListModel> items;
  const _ProblemsSection(this.items);

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Problem List',
      count: items.length,
      form: const ProblemForm(),
      children: items.map((p) => _ProblemTile(p)).toList(),
    );
  }
}

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

// ── Procedures ────────────────────────────────────────────────────────────────

class _ProceduresSection extends StatelessWidget {
  final List<ProcedureModel> items;
  const _ProceduresSection(this.items);

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Procedures',
      count: items.length,
      form: const ProcedureForm(),
      children: items.map((p) => _ProcedureTile(p)).toList(),
    );
  }
}

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

// ── Immunizations ─────────────────────────────────────────────────────────────

class _ImmunizationsSection extends StatelessWidget {
  final List<ImmunizationModel> items;
  const _ImmunizationsSection(this.items);

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Immunizations',
      count: items.length,
      form: const ImmunizationForm(),
      children: items.map((i) => _ImmunizationTile(i)).toList(),
    );
  }
}

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
