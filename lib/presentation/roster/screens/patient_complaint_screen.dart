// lib/presentation/roster/screens/patient_complaint_screen.dart
//
// Focused consultation view shown when a doctor opens a patient from the
// daily roster. Shows the chief complaint and relevant clinical context,
// with a sticky action bar for common consult actions.
// The full patient record is accessible via the top-right button but is
// not the default view.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../core/platform.dart';
import '../../../data/models/clinical_record_models.dart';
import '../../../data/models/intra_grant_models.dart';
import '../../../data/models/patient_models.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/clinical_provider.dart';
import '../../../data/providers/intra_grant_provider.dart';
import '../../../data/providers/patient_provider.dart';
import '../../../data/providers/referral_provider.dart';
import '../../access_grants/widgets/transfer_request_sheet.dart';
import '../../patients/screens/patient_detail_screen.dart';
import '../../patients/widgets/clinical_forms.dart';
import '../../referrals/widgets/create_referral_sheet.dart';
import '../widgets/consultation_note_sheet.dart';

class PatientComplaintScreen extends StatefulWidget {
  final PatientModel patient;
  final RosterEntryModel entry;

  const PatientComplaintScreen({
    super.key,
    required this.patient,
    required this.entry,
  });

  @override
  State<PatientComplaintScreen> createState() =>
      _PatientComplaintScreenState();
}

class _PatientComplaintScreenState extends State<PatientComplaintScreen> {
  List<ClinicalNoteModel> _notes = [];
  bool _loadingNotes = true;
  bool _actionInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNotes());
  }

  Future<void> _loadNotes() async {
    try {
      final repo = context.read<IntraGrantProvider>().repository;
      final notes = await repo.getPatientNotes(widget.patient.id);
      if (mounted) setState(() => _notes = notes);
    } catch (_) {
      // Notes are supplementary — silently ignore load failures
    } finally {
      if (mounted) setState(() => _loadingNotes = false);
    }
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _actionInProgress = true);
    try {
      final repo = context.read<ClinicalProvider>().repository;
      await repo.updateRosterEntry(
        widget.patient.id,
        widget.entry.id,
        {'status': status, 'version': widget.entry.version},
      );
      if (mounted) {
        final label = status == 'seen' ? 'Consultation concluded.' : 'Patient admitted.';
        showAdaptiveToast(context, label, type: ToastType.success);
        Navigator.of(context).pop(true); // signal roster to refresh
      }
    } catch (_) {
      if (mounted) {
        showAdaptiveToast(context, 'Failed to update status', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _openAppointmentForm() async {
    // Ensure ClinicalProvider knows the current patient before the form submits
    context.read<ClinicalProvider>().loadAll(widget.patient.id);

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<ClinicalProvider>(),
        child: const AppointmentForm(),
      ),
    );
    if (created == true && mounted) {
      showAdaptiveToast(context, 'Appointment booked.', type: ToastType.success);
    }
  }

  Future<void> _openReferralSheet() async {
    if (widget.patient.globalPatientId == null) {
      showAdaptiveToast(context,
          'Patient has no global ID. Cannot create referral.',
          type: ToastType.error);
      return;
    }
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => CreateReferralSheet(patient: widget.patient),
    );
    if (created == true && mounted) {
      context.read<ReferralProvider>().loadReferrals(
            currentTenantId: context.read<AuthProvider>().activeTenantId ?? '',
          );
    }
  }

  Future<void> _openTransferSheet() async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransferRequestSheet(
        patientId: widget.patient.id,
        rosterEntryId: widget.entry.id,
      ),
    );
  }

  Future<void> _confirmAdmit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Admit patient?'),
        content: Text(
            '${widget.patient.fullName} will be marked as admitted.'),
        actions: [
          AdaptiveTextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          AdaptiveFilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Admit'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) _updateStatus('admitted');
  }

  void _openFullRecord() {
    context.read<PatientProvider>().setSelectedPatient(widget.patient);
    Navigator.of(context).push(
      kIsIOS
          ? CupertinoPageRoute(
              builder: (_) =>
                  PatientDetailScreen(patient: widget.patient))
          : MaterialPageRoute(
              builder: (_) =>
                  PatientDetailScreen(patient: widget.patient)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final patient = widget.patient;
    final entry   = widget.entry;

    final body = _buildBody(patient, entry);

    if (kIsIOS) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(patient.fullName,
              style: const TextStyle(fontSize: 16)),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _openFullRecord,
            child: const Text('Full Record',
                style: TextStyle(fontSize: 14)),
          ),
        ),
        child: SafeArea(child: body),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(patient.fullName),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Full Record'),
            onPressed: _openFullRecord,
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildBody(PatientModel patient, RosterEntryModel entry) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Status + triage row ─────────────────────────────────
                Row(
                  children: [
                    _TriageChip(severity: entry.triageSeverity),
                    const SizedBox(width: 8),
                    _StatusChip(status: entry.status),
                    if (entry.isCarriedOver) ...[
                      const SizedBox(width: 8),
                      _CarryOverBadge(count: entry.carryOverCount),
                    ],
                  ],
                ),
                const SizedBox(height: 14),

                // ── Chief complaint ─────────────────────────────────────
                _SectionCard(
                  icon: Icons.report_problem_outlined,
                  title: 'Chief Complaint',
                  child: Text(
                    entry.chiefComplaint?.isNotEmpty == true
                        ? entry.chiefComplaint!
                        : 'No complaint recorded',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: entry.chiefComplaint?.isNotEmpty == true
                          ? Colors.black87
                          : AppTheme.gray600,
                      fontStyle: entry.chiefComplaint?.isNotEmpty == true
                          ? FontStyle.normal
                          : FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Patient summary ─────────────────────────────────────
                _SectionCard(
                  icon: Icons.person_outline,
                  title: 'Patient',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _InfoPill(patient.ageDisplay),
                          const SizedBox(width: 6),
                          _InfoPill(_capitalize(patient.gender)),
                          if (patient.bloodType != null) ...[
                            const SizedBox(width: 6),
                            _InfoPill(patient.bloodType!),
                          ],
                        ],
                      ),
                      if (patient.hasCriticalAllergies) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.warning,
                                size: 14, color: AppTheme.errorColor),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Critical allergies: '
                                '${patient.allergies.where((a) => a.isLifeThreatening || a.isSevere).map((a) => a.name).join(', ')}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.errorColor,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (patient.currentMedications.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Current meds: '
                          '${patient.currentMedications.take(3).map((m) => m.name).join(', ')}'
                          '${patient.currentMedications.length > 3 ? ' +${patient.currentMedications.length - 3} more' : ''}',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.gray600),
                        ),
                      ],
                      if (patient.chronicConditions.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Chronic: '
                          '${patient.chronicConditions.take(3).join(', ')}'
                          '${patient.chronicConditions.length > 3 ? ' +${patient.chronicConditions.length - 3} more' : ''}',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.gray600),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Consultation notes ──────────────────────────────────
                _SectionCard(
                  icon: Icons.notes_outlined,
                  title: 'Consultation Notes',
                  trailing: _loadingNotes
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child:
                              CircularProgressIndicator(strokeWidth: 2))
                      : null,
                  child: _notes.isEmpty
                      ? Text(
                          _loadingNotes
                              ? ''
                              : 'No notes yet — tap Notes below to add one.',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.gray600,
                              fontStyle: FontStyle.italic),
                        )
                      : Column(
                          children: _notes
                              .take(5)
                              .map((n) => _NotePreview(note: n))
                              .toList(),
                        ),
                ),
                const SizedBox(height: 80), // bottom action bar clearance
              ],
            ),
          ),
        ),

        // ── Sticky action bar ───────────────────────────────────────────
        _ActionBar(
          inProgress: _actionInProgress,
          onNotes: () async {
            final saved =
                await showConsultationNoteSheet(context, patient.id);
            if (saved && mounted) _loadNotes();
          },
          onAppointment: _openAppointmentForm,
          onRefer: _openReferralSheet,
          onTransfer: _openTransferSheet,
          onSeen: () => _updateStatus('seen'),
          onAdmit: _confirmAdmit,
          currentStatus: entry.status,
        ),
      ],
    );
  }
}

// ── Action bar ────────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  final bool inProgress;
  final VoidCallback onNotes;
  final VoidCallback onAppointment;
  final VoidCallback onRefer;
  final VoidCallback onTransfer;
  final VoidCallback onSeen;
  final VoidCallback onAdmit;
  final String currentStatus;

  const _ActionBar({
    required this.inProgress,
    required this.onNotes,
    required this.onAppointment,
    required this.onRefer,
    required this.onTransfer,
    required this.onSeen,
    required this.onAdmit,
    required this.currentStatus,
  });

  bool get _isClosed =>
      const ['seen', 'admitted', 'referred', 'cancelled'].contains(currentStatus);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
          8, 10, 8, 10 + MediaQuery.of(context).padding.bottom),
      child: inProgress
          ? const Center(
              child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2)))
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _BarBtn(
                  icon: Icons.edit_note,
                  label: 'Notes',
                  color: AppTheme.primaryColor,
                  onTap: onNotes,
                ),
                _BarBtn(
                  icon: Icons.calendar_today_outlined,
                  label: 'Appt',
                  color: Colors.teal,
                  onTap: onAppointment,
                ),
                _BarBtn(
                  icon: Icons.send_outlined,
                  label: 'Refer',
                  color: Colors.indigo,
                  onTap: onRefer,
                ),
                _BarBtn(
                  icon: Icons.swap_horiz,
                  label: 'Transfer',
                  color: Colors.orange.shade700,
                  onTap: _isClosed ? null : onTransfer,
                ),
                _BarBtn(
                  icon: Icons.check_circle_outline,
                  label: 'Seen',
                  color: AppTheme.successColor,
                  onTap: _isClosed ? null : onSeen,
                ),
                _BarBtn(
                  icon: Icons.local_hospital_outlined,
                  label: 'Admit',
                  color: Colors.deepOrange,
                  onTap: _isClosed ? null : onAdmit,
                ),
              ],
            ),
    );
  }
}

class _BarBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _BarBtn({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final effectiveColor = enabled ? color : Colors.grey.shade400;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: effectiveColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: effectiveColor, size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: effectiveColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: AppTheme.gray600),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.gray600,
                    letterSpacing: 0.5,
                  ),
                ),
                if (trailing != null) ...[
                  const Spacer(),
                  trailing!,
                ],
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _NotePreview extends StatelessWidget {
  final ClinicalNoteModel note;
  const _NotePreview({required this.note});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  note.displayTitle,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              Text(
                '${note.authoredAt.day.toString().padLeft(2, '0')}/'
                '${note.authoredAt.month.toString().padLeft(2, '0')}/'
                '${note.authoredAt.year}',
                style: TextStyle(fontSize: 11, color: AppTheme.gray600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            note.body.length > 120
                ? '${note.body.substring(0, 120)}…'
                : note.body,
            style: TextStyle(fontSize: 12, color: AppTheme.gray600, height: 1.4),
          ),
          const Divider(height: 16),
        ],
      ),
    );
  }
}

class _TriageChip extends StatelessWidget {
  final String? severity;
  const _TriageChip({this.severity});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (severity) {
      'critical' => (AppTheme.errorColor,   'CRITICAL'),
      'urgent'   => (AppTheme.warningColor, 'URGENT'),
      'moderate' => (Colors.blue,           'MODERATE'),
      'low'      => (AppTheme.successColor, 'LOW'),
      _          => (AppTheme.gray600,      'UNSET'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'waiting'         => (AppTheme.warningColor, 'Waiting'),
      'in_consultation' => (Colors.blue,           'In consultation'),
      'seen'            => (AppTheme.successColor, 'Seen'),
      'admitted'        => (Colors.purple,         'Admitted'),
      'referred'        => (Colors.indigo,         'Referred'),
      'carried_over'    => (AppTheme.gray600,      'Carried over'),
      _                 => (AppTheme.gray600,      status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _CarryOverBadge extends StatelessWidget {
  final int count;
  const _CarryOverBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.gray600.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.gray600.withValues(alpha: 0.3)),
      ),
      child: Text(
        'Carried over ×$count',
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppTheme.gray600),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  const _InfoPill(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, color: AppTheme.primaryColor)),
    );
  }
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
