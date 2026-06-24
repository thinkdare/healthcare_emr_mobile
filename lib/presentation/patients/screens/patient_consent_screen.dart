// lib/presentation/patients/screens/patient_consent_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/patient_consent_models.dart';
import '../../../data/providers/patient_consent_provider.dart';

const _consentTypes = [
  'data_sharing',
  'cross_facility_access',
  'research',
  'marketing',
  'portal_access',
];

const _legalBases = [
  ('consent', 'Consent'),
  ('vital_interest', 'Vital Interest'),
  ('public_task', 'Public Task'),
  ('legitimate_interest', 'Legitimate Interest'),
  ('legal_obligation', 'Legal Obligation'),
];

class PatientConsentScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const PatientConsentScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<PatientConsentScreen> createState() => _PatientConsentScreenState();
}

class _PatientConsentScreenState extends State<PatientConsentScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PatientConsentProvider>().load(widget.patientId);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Consent — ${widget.patientName}'),
        bottom: TabBar(controller: _tabs, tabs: const [
          Tab(text: 'Consents'),
          Tab(text: 'History'),
          Tab(text: 'Notifications'),
        ]),
      ),
      body: Consumer<PatientConsentProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.consents.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              if (provider.error != null)
                Container(
                  width: double.infinity,
                  color: Colors.red.shade50,
                  padding: const EdgeInsets.all(12),
                  child: Text(provider.error!,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _ConsentsTab(patientId: widget.patientId, provider: provider),
                    _HistoryTab(events: provider.history),
                    _NotificationsTab(patientId: widget.patientId, provider: provider),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ConsentsTab extends StatelessWidget {
  final String patientId;
  final PatientConsentProvider provider;

  const _ConsentsTab({required this.patientId, required this.provider});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => provider.load(patientId),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: _consentTypes.map((type) {
          final existing =
              provider.consents.where((c) => c.consentType == type).cast<PatientConsentModel?>().firstOrNull;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              title: Text(existing?.consentTypeLabel ?? _label(type)),
              subtitle: Text(existing == null
                  ? 'Not recorded'
                  : existing.given
                      ? 'Given · ${existing.legalBasis.replaceAll('_', ' ')}'
                      : 'Revoked'),
              trailing: Switch(
                value: existing?.given ?? false,
                onChanged: provider.isSubmitting
                    ? null
                    : (value) => _onToggle(context, type, existing, value),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _label(String type) => switch (type) {
        'data_sharing' => 'Data Sharing',
        'cross_facility_access' => 'Cross-Facility Access',
        'research' => 'Research',
        'marketing' => 'Marketing',
        'portal_access' => 'Portal Access',
        _ => type,
      };

  Future<void> _onToggle(
      BuildContext context, String type, PatientConsentModel? existing, bool value) async {
    if (!value && existing != null && existing.given) {
      final reasonCtrl = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Revoke consent?'),
          content: TextField(
            controller: reasonCtrl,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
            maxLines: 2,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Revoke')),
          ],
        ),
      );
      if (confirmed != true) return;
      final ok = await provider.revokeConsent(patientId, type,
          documentVersion: 'v1', notes: reasonCtrl.text.trim());
      if (context.mounted && !ok) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(provider.error ?? 'Failed to revoke')));
      }
      return;
    }

    final legalBasis = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Legal basis'),
        children: _legalBases
            .map((b) => SimpleDialogOption(
                  onPressed: () => Navigator.of(ctx).pop(b.$1),
                  child: Text(b.$2),
                ))
            .toList(),
      ),
    );
    if (legalBasis == null) return;

    final ok = await provider.recordConsent(
      patientId,
      consentType: type,
      legalBasis: legalBasis,
      given: value,
      documentVersion: 'v1',
    );
    if (context.mounted && !ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(provider.error ?? 'Failed to record consent')));
    }
  }
}

class _HistoryTab extends StatelessWidget {
  final List<PatientConsentEventModel> events;
  const _HistoryTab({required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Center(
        child: Text('No consent history yet.', style: TextStyle(color: Colors.grey.shade600)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (_, i) {
        final e = events[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text('${e.action.toUpperCase()} · ${e.consentType.replaceAll('_', ' ')}'),
            subtitle: Text(
                '${e.actorName ?? e.actorType} · ${_formatDate(e.occurredAt)}${e.notes != null ? '\n${e.notes}' : ''}'),
            isThreeLine: e.notes != null,
          ),
        );
      },
    );
  }
}

class _NotificationsTab extends StatefulWidget {
  final String patientId;
  final PatientConsentProvider provider;
  const _NotificationsTab({required this.patientId, required this.provider});

  @override
  State<_NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<_NotificationsTab> {
  late NotificationPreferencesModel _prefs;

  @override
  void initState() {
    super.initState();
    _prefs = widget.provider.preferences;
  }

  Future<void> _toggle(NotificationPreferencesModel updated) async {
    setState(() => _prefs = updated);
    final ok = await widget.provider.updatePreferences(widget.patientId, updated);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(widget.provider.error ?? 'Failed to update')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: const Text('Appointment Reminders'),
          value: _prefs.appointmentReminders,
          onChanged: (v) => _toggle(_prefs.copyWith(appointmentReminders: v)),
        ),
        SwitchListTile(
          title: const Text('SMS'),
          value: _prefs.sms,
          onChanged: (v) => _toggle(_prefs.copyWith(sms: v)),
        ),
        SwitchListTile(
          title: const Text('Email'),
          value: _prefs.email,
          onChanged: (v) => _toggle(_prefs.copyWith(email: v)),
        ),
        SwitchListTile(
          title: const Text('Push Notifications'),
          value: _prefs.push,
          onChanged: (v) => _toggle(_prefs.copyWith(push: v)),
        ),
      ],
    );
  }
}

String _formatDate(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}/'
    '${dt.month.toString().padLeft(2, '0')}/'
    '${dt.year}';

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
