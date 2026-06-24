// lib/presentation/access_grants/screens/cross_tenant_patient_screen.dart

import 'package:flutter/material.dart';
import '../../../data/models/access_grant_models.dart';
import '../../../data/models/cross_tenant_patient_models.dart';
import '../../../data/repositories/access_grant_repository.dart';

/// Read-only view of a patient's record at another facility, authorized by
/// an approved [AccessGrantModel]. Backed by GET /cross-tenant-patients/{id}
/// and its sub-resources — every call is server-side gated by the grant's
/// accessible_data_types, so we only request what the grant actually permits.
class CrossTenantPatientScreen extends StatefulWidget {
  final AccessGrantRepository repository;
  final AccessGrantModel grant;

  const CrossTenantPatientScreen({
    super.key,
    required this.repository,
    required this.grant,
  });

  @override
  State<CrossTenantPatientScreen> createState() => _CrossTenantPatientScreenState();
}

class _CrossTenantPatientScreenState extends State<CrossTenantPatientScreen> {
  bool _loading = true;
  String? _error;
  CrossTenantPatientModel? _patient;
  List<CrossTenantPrescriptionModel> _prescriptions = [];
  List<CrossTenantLabResultModel> _labResults = [];
  List<CrossTenantAppointmentModel> _appointments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final globalPatientId = widget.grant.globalPatientId;
    if (globalPatientId == null) {
      setState(() {
        _loading = false;
        _error = 'This grant has no linked patient record.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final types = widget.grant.accessibleDataTypes;
      final results = await Future.wait([
        widget.repository.getCrossTenantPatient(globalPatientId),
        types.contains('prescriptions')
            ? widget.repository.getCrossTenantPrescriptions(globalPatientId)
            : Future.value(<CrossTenantPrescriptionModel>[]),
        types.contains('lab_results')
            ? widget.repository.getCrossTenantLabResults(globalPatientId)
            : Future.value(<CrossTenantLabResultModel>[]),
        types.contains('appointments')
            ? widget.repository.getCrossTenantAppointments(globalPatientId)
            : Future.value(<CrossTenantAppointmentModel>[]),
      ]);

      if (!mounted) return;
      setState(() {
        _patient = results[0] as CrossTenantPatientModel;
        _prescriptions = results[1] as List<CrossTenantPrescriptionModel>;
        _labResults = results[2] as List<CrossTenantLabResultModel>;
        _appointments = results[3] as List<CrossTenantAppointmentModel>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_patient?.fullName ?? 'Patient Record'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.shield_outlined, size: 16, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Viewing via cross-facility access grant (${widget.grant.accessLevelDisplay})',
                                style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _Section(title: 'Demographics', children: [
                        _InfoRow('Date of birth', _patient!.dateOfBirth ?? '—'),
                        _InfoRow('Gender', _patient!.gender ?? '—'),
                        _InfoRow('Blood type', _patient!.bloodType ?? '—'),
                      ]),
                      if (_patient!.allergies != null ||
                          _patient!.currentMedications != null ||
                          _patient!.chronicConditions != null ||
                          _patient!.medicalHistory != null)
                        _Section(title: 'Clinical Summary', children: [
                          if (_patient!.allergies != null)
                            _InfoRow('Allergies', _patient!.allergies!),
                          if (_patient!.currentMedications != null)
                            _InfoRow('Current medications', _patient!.currentMedications!),
                          if (_patient!.chronicConditions != null)
                            _InfoRow('Chronic conditions', _patient!.chronicConditions!),
                          if (_patient!.medicalHistory != null)
                            _InfoRow('Medical history', _patient!.medicalHistory!),
                        ]),
                      if (widget.grant.accessibleDataTypes.contains('prescriptions'))
                        _Section(
                          title: 'Prescriptions',
                          children: _prescriptions.isEmpty
                              ? [const _EmptyHint(text: 'No prescriptions.')]
                              : _prescriptions
                                  .map((p) => _ListCard(
                                        title: p.medicationName,
                                        subtitle:
                                            [p.dosage, p.frequency].whereType<String>().join(' · '),
                                        trailing: p.status,
                                      ))
                                  .toList(),
                        ),
                      if (widget.grant.accessibleDataTypes.contains('lab_results'))
                        _Section(
                          title: 'Lab Results',
                          children: _labResults.isEmpty
                              ? [const _EmptyHint(text: 'No lab results.')]
                              : _labResults
                                  .map((r) => _ListCard(
                                        title: r.testName,
                                        subtitle: r.testType ?? '',
                                        trailing: r.status,
                                      ))
                                  .toList(),
                        ),
                      if (widget.grant.accessibleDataTypes.contains('appointments'))
                        _Section(
                          title: 'Appointments',
                          children: _appointments.isEmpty
                              ? [const _EmptyHint(text: 'No appointments.')]
                              : _appointments
                                  .map((a) => _ListCard(
                                        title: a.appointmentType ?? 'Appointment',
                                        subtitle: a.appointmentDate ?? '',
                                        trailing: a.status,
                                      ))
                                  .toList(),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text('$label:',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailing;
  const _ListCard({required this.title, required this.subtitle, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: subtitle.isEmpty ? null : Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: Text(trailing.replaceAll('_', ' '), style: const TextStyle(fontSize: 11)),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
      );
}
