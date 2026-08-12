// lib/presentation/referrals/screens/referral_detail_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/platform.dart';
import '../../../data/models/referral_models.dart';
import '../../../data/providers/referral_provider.dart';
import '../widgets/referral_message_thread.dart';

class ReferralDetailScreen extends StatefulWidget {
  final ReferralModel referral;

  const ReferralDetailScreen({super.key, required this.referral});

  @override
  State<ReferralDetailScreen> createState() => _ReferralDetailScreenState();
}

class _ReferralDetailScreenState extends State<ReferralDetailScreen> {
  late ReferralModel _referral;

  @override
  void initState() {
    super.initState();
    _referral = widget.referral;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDetail());
  }

  Future<void> _loadDetail() async {
    try {
      final full = await context
          .read<ReferralProvider>()
          .repository
          .show(_referral.id);
      if (mounted) setState(() => _referral = full);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final r = _referral;
    return kIsIOS
        ? CupertinoPageScaffold(
            navigationBar:
                const CupertinoNavigationBar(middle: Text('Referral')),
            child: SafeArea(child: _buildBody(r)),
          )
        : Scaffold(
            appBar: AppBar(title: const Text('Referral')),
            body: _buildBody(r),
          );
  }

  Widget _buildBody(ReferralModel r) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderCard(referral: r),
          const SizedBox(height: 12),
          if (r.reason != null)
            _Section(title: 'Reason', body: r.reason!, expanded: true),
          if (r.clinicalSummary != null)
            _Section(title: 'Clinical Summary', body: r.clinicalSummary!),
          if (r.relevantHistory != null)
            _Section(title: 'Relevant History', body: r.relevantHistory!),
          if (r.currentMedications != null)
            _Section(
                title: 'Current Medications', body: r.currentMedications!),
          if (r.diagnosticResults != null)
            _Section(
                title: 'Diagnostic Results', body: r.diagnosticResults!),
          if (r.consultationNotes != null)
            _Section(
                title: 'Consultation Notes',
                body: r.consultationNotes!,
                expanded: true),
          if (r.recommendations != null)
            _Section(title: 'Recommendations', body: r.recommendations!),
          if (r.requiresFollowUp && r.followUpDate != null)
            _InfoRow(label: 'Follow-up date', value: r.followUpDate!),
          if (r.appointmentDate != null) ...[
            _InfoRow(
                label: 'Appointment',
                value: r.appointmentDate!.split('T').first),
            if (r.appointmentLocation != null)
              _InfoRow(
                  label: 'Location', value: r.appointmentLocation!),
          ],
          if (r.statusHistory.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Status Timeline',
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            ...r.statusHistory.map((h) => _TimelineEntry(entry: h)),
          ],
          const SizedBox(height: 24),
          _ActionBar(
            referral: r,
            onUpdated: (updated) => setState(() => _referral = updated),
          ),
          ReferralMessageThread(
            referralId: r.id,
            isOpen: r.isOpen,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final ReferralModel r;
  const _HeaderCard({required ReferralModel referral}) : r = referral;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(r.patientName ?? 'Patient',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 18)),
                ),
                _UrgencyBadge(urgency: r.urgency),
              ],
            ),
            if (r.patientDob != null)
              Text(r.patientDob!,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600)),
            const Divider(height: 16),
            _InfoRow(label: 'Specialty', value: r.specialty),
            _InfoRow(label: 'From', value: r.fromTenantName),
            _InfoRow(label: 'To', value: r.toTenantName),
            _InfoRow(
                label: 'Referred by', value: r.referringProviderName),
            if (r.referredToProviderName != null)
              _InfoRow(
                  label: 'Referred to',
                  value: r.referredToProviderName!),
            _InfoRow(
                label: 'Date', value: r.referredAt.split('T').first),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatefulWidget {
  final String title;
  final String body;
  final bool expanded;

  const _Section({
    required this.title,
    required this.body,
    this.expanded = false,
  });

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.expanded;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        initiallyExpanded: _expanded,
        title: Text(widget.title,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(widget.body,
                style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final ReferralStatusHistoryModel entry;
  const _TimelineEntry({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
                color: Colors.blue, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.from != null
                  ? '${entry.from} → ${entry.to}'
                  : entry.to,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Text(entry.at.split('T').first,
              style: TextStyle(
                  fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final ReferralModel referral;
  final void Function(ReferralModel) onUpdated;

  const _ActionBar({required this.referral, required this.onUpdated});

  @override
  Widget build(BuildContext context) {
    final r = referral;
    if (!r.isOpen) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          if (r.canAccept)
            Expanded(
                child: _ActionButton(
              label: 'Accept',
              color: Colors.green,
              onTap: () => _accept(context),
            )),
          if (r.canSchedule)
            Expanded(
                child: _ActionButton(
              label: 'Schedule',
              color: Colors.blue,
              onTap: () => _schedule(context),
            )),
          if (r.canComplete)
            Expanded(
                child: _ActionButton(
              label: 'Mark complete',
              color: Colors.purple,
              onTap: () => _complete(context),
            )),
          if (r.canCancel) ...[
            if (r.canAccept || r.canSchedule || r.canComplete)
              const SizedBox(width: 8),
            Expanded(
                child: _ActionButton(
              label: 'Cancel',
              color: Colors.red,
              outlined: true,
              onTap: () => _cancel(context),
            )),
          ],
        ],
      ),
    );
  }

  Future<void> _accept(BuildContext context) async {
    final provider = context.read<ReferralProvider>();
    final ok = await provider.accept(referral.id);
    if (ok && context.mounted) {
      final updated = provider.referrals.firstWhere(
          (r) => r.id == referral.id,
          orElse: () => referral);
      onUpdated(updated);
    }
  }

  Future<void> _schedule(BuildContext context) async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ScheduleSheet(),
    );
    if (result == null || !context.mounted) return;
    final provider = context.read<ReferralProvider>();
    final ok = await provider.schedule(
        referral.id, result['date']!, result['location']);
    if (ok && context.mounted) {
      final updated = provider.referrals.firstWhere(
          (r) => r.id == referral.id,
          orElse: () => referral);
      onUpdated(updated);
    }
  }

  Future<void> _complete(BuildContext context) async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CompleteSheet(),
    );
    if (result == null || !context.mounted) return;
    final provider = context.read<ReferralProvider>();
    final ok = await provider.complete(
        referral.id, result['notes']!, result['recommendations']);
    if (ok && context.mounted) {
      final updated = provider.referrals.firstWhere(
          (r) => r.id == referral.id,
          orElse: () => referral);
      onUpdated(updated);
    }
  }

  Future<void> _cancel(BuildContext context) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CancelSheet(),
    );
    if (reason == null || !context.mounted) return;
    final provider = context.read<ReferralProvider>();
    final ok = await provider.cancel(referral.id, reason);
    if (ok && context.mounted) {
      Navigator.of(context).pop();
    }
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool outlined;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return outlined
        ? OutlinedButton(
            onPressed: onTap,
            style:
                OutlinedButton.styleFrom(foregroundColor: color),
            child: Text(label),
          )
        : ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white),
            child: Text(label),
          );
  }
}

// ── Action sheets ──────────────────────────────────────────────────────────

class _ScheduleSheet extends StatefulWidget {
  const _ScheduleSheet();

  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  String? _date;
  final _locationCtrl = TextEditingController();

  @override
  void dispose() {
    _locationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 24, 16,
          16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Schedule Appointment',
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate:
                    DateTime.now().add(const Duration(days: 1)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now()
                    .add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(
                    () => _date = picked.toIso8601String());
              }
            },
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(_date == null
                ? 'Select appointment date'
                : _date!.split('T').first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _locationCtrl,
            decoration: const InputDecoration(
              labelText: 'Location (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _date == null
                ? null
                : () => Navigator.of(context).pop({
                      'date': _date!,
                      'location': _locationCtrl.text.trim(),
                    }),
            child: const Text('Schedule'),
          ),
        ],
      ),
    );
  }
}

class _CompleteSheet extends StatefulWidget {
  const _CompleteSheet();

  @override
  State<_CompleteSheet> createState() => _CompleteSheetState();
}

class _CompleteSheetState extends State<_CompleteSheet> {
  final _notesCtrl = TextEditingController();
  final _recsCtrl = TextEditingController();

  @override
  void dispose() {
    _notesCtrl.dispose();
    _recsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 24, 16,
          16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Mark as Complete',
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 16),
          TextField(
            controller: _notesCtrl,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Consultation notes *',
              hintText: 'Minimum 10 characters',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _recsCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Recommendations (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _notesCtrl.text.trim().length < 10
                ? null
                : () => Navigator.of(context).pop({
                      'notes': _notesCtrl.text.trim(),
                      'recommendations': _recsCtrl.text.trim(),
                    }),
            child: const Text('Mark complete'),
          ),
        ],
      ),
    );
  }
}

class _CancelSheet extends StatefulWidget {
  const _CancelSheet();

  @override
  State<_CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends State<_CancelSheet> {
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 24, 16,
          16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Cancel Referral',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.red)),
          const SizedBox(height: 16),
          TextField(
            controller: _reasonCtrl,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Reason *',
              hintText: 'Minimum 10 characters',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _reasonCtrl.text.trim().length < 10
                ? null
                : () =>
                    Navigator.of(context).pop(_reasonCtrl.text.trim()),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            child: const Text('Confirm cancellation'),
          ),
        ],
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _UrgencyBadge extends StatelessWidget {
  final String urgency;
  const _UrgencyBadge({required this.urgency});

  @override
  Widget build(BuildContext context) {
    if (urgency == 'routine') return const SizedBox.shrink();
    final (color, label) = urgency == 'emergency'
        ? (Colors.red, 'EMERGENCY')
        : (Colors.orange, 'URGENT');
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }
}
