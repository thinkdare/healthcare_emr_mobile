// lib/presentation/referrals/widgets/create_referral_sheet.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/platform.dart';
import '../../../data/models/patient_models.dart';
import '../../../data/providers/referral_provider.dart';
import '../../../data/repositories/facility_repository.dart';

class CreateReferralSheet extends StatefulWidget {
  final PatientModel patient;

  const CreateReferralSheet({super.key, required this.patient});

  @override
  State<CreateReferralSheet> createState() => _CreateReferralSheetState();
}

class _CreateReferralSheetState extends State<CreateReferralSheet> {
  final _specialtyCtrl    = TextEditingController();
  final _reasonCtrl       = TextEditingController();
  final _summaryCtrl      = TextEditingController();
  final _historyCtrl      = TextEditingController();
  final _medsCtrl         = TextEditingController();
  final _diagnosticsCtrl  = TextEditingController();

  String _urgency = 'routine';
  bool _requiresFollowUp = false;
  String? _followUpDate;
  Map<String, dynamic>? _selectedFacility;
  Map<String, dynamic>? _selectedProvider;
  List<Map<String, dynamic>> _facilities = [];
  List<Map<String, dynamic>> _facilityProviders = [];
  bool _loadingFacilities = false;
  bool _loadingProviders = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFacilities();
  }

  @override
  void dispose() {
    _specialtyCtrl.dispose();
    _reasonCtrl.dispose();
    _summaryCtrl.dispose();
    _historyCtrl.dispose();
    _medsCtrl.dispose();
    _diagnosticsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFacilities() async {
    setState(() => _loadingFacilities = true);
    try {
      final apiClient =
          context.read<ReferralProvider>().repository.apiClient;
      final repo = FacilityRepository(apiClient: apiClient);
      final facilities = await repo.listTenants();
      setState(() => _facilities = facilities);
    } catch (_) {
      setState(() => _error = 'Failed to load facilities.');
    } finally {
      setState(() => _loadingFacilities = false);
    }
  }

  Future<void> _loadProviders(String tenantId) async {
    setState(() {
      _loadingProviders = true;
      _selectedProvider = null;
      _facilityProviders = [];
    });
    try {
      final apiClient =
          context.read<ReferralProvider>().repository.apiClient;
      final repo = FacilityRepository(apiClient: apiClient);
      final providers = await repo.listStaffAtTenant(tenantId);
      setState(() => _facilityProviders = providers);
    } catch (_) {
      setState(() => _facilityProviders = []);
    } finally {
      setState(() => _loadingProviders = false);
    }
  }

  bool get _isValid =>
      _selectedFacility != null &&
      _specialtyCtrl.text.trim().isNotEmpty &&
      _reasonCtrl.text.trim().length >= 10;

  Future<void> _submit() async {
    if (!_isValid) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final data = <String, dynamic>{
      'master_patient_id': widget.patient.globalPatientId,
      'to_tenant_id':      _selectedFacility!['id'],
      'specialty':         _specialtyCtrl.text.trim(),
      'urgency':           _urgency,
      'reason':            _reasonCtrl.text.trim(),
      if (_selectedProvider != null)
        'referred_to_provider_id': _selectedProvider!['id'],
      if (_summaryCtrl.text.trim().isNotEmpty)
        'clinical_summary': _summaryCtrl.text.trim(),
      if (_historyCtrl.text.trim().isNotEmpty)
        'relevant_history': _historyCtrl.text.trim(),
      if (_medsCtrl.text.trim().isNotEmpty)
        'current_medications': _medsCtrl.text.trim(),
      if (_diagnosticsCtrl.text.trim().isNotEmpty)
        'diagnostic_results': _diagnosticsCtrl.text.trim(),
      'requires_follow_up': _requiresFollowUp,
      if (_requiresFollowUp && _followUpDate != null)
        'follow_up_date': _followUpDate,
    };

    final provider = context.read<ReferralProvider>();
    final created = await provider.create(data);
    if (!mounted) return;

    setState(() => _submitting = false);

    if (created != null) {
      Navigator.of(context).pop(true);
      showAdaptiveToast(context, 'Referral sent');
    } else {
      setState(() => _error = provider.error ?? 'Failed to create referral.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Refer Patient',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 17)),
                ),
                Text(widget.patient.fullName,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_error != null)
            Container(
              color: Colors.red.shade50,
              padding: const EdgeInsets.all(12),
              child: Text(_error!,
                  style: TextStyle(
                      color: Colors.red.shade700, fontSize: 12)),
            ),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Destination facility
                  const Text('Destination facility *',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87)),
                  const SizedBox(height: 6),
                  _loadingFacilities
                      ? const Center(
                          child: CircularProgressIndicator())
                      : DropdownButtonFormField<Map<String, dynamic>>(
                          value: _selectedFacility,
                          hint: const Text('Select facility'),
                          decoration: const InputDecoration(
                              border: OutlineInputBorder()),
                          items: _facilities
                              .map((f) => DropdownMenuItem(
                                    value: f,
                                    child: Text(
                                        f['name'] as String? ?? ''),
                                  ))
                              .toList(),
                          onChanged: (f) {
                            setState(() => _selectedFacility = f);
                            if (f != null) {
                              _loadProviders(f['id'] as String);
                            }
                          },
                        ),
                  const SizedBox(height: 14),
                  // Optional provider
                  const Text('Specific provider (optional)',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87)),
                  const SizedBox(height: 6),
                  _loadingProviders
                      ? const LinearProgressIndicator()
                      : DropdownButtonFormField<Map<String, dynamic>>(
                          value: _selectedProvider,
                          hint: const Text('Any available provider'),
                          decoration: const InputDecoration(
                              border: OutlineInputBorder()),
                          items: [
                            const DropdownMenuItem<Map<String, dynamic>>(
                              child: Text('Any available provider'),
                            ),
                            ..._facilityProviders.map(
                              (p) => DropdownMenuItem(
                                value: p,
                                child: Text(
                                    p['name'] as String? ?? ''),
                              ),
                            ),
                          ],
                          onChanged: (p) =>
                              setState(() => _selectedProvider = p),
                        ),
                  const SizedBox(height: 14),
                  // Specialty
                  TextField(
                    controller: _specialtyCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Specialty *',
                      hintText: 'e.g. Cardiology, Neurology',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Urgency
                  const Text('Urgency *',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87)),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                          value: 'routine', label: Text('Routine')),
                      ButtonSegment(
                          value: 'urgent', label: Text('Urgent')),
                      ButtonSegment(
                          value: 'emergency',
                          label: Text('Emergency')),
                    ],
                    selected: {_urgency},
                    onSelectionChanged: (s) =>
                        setState(() => _urgency = s.first),
                  ),
                  const SizedBox(height: 14),
                  // Reason
                  TextField(
                    controller: _reasonCtrl,
                    maxLines: 4,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Reason *',
                      hintText: 'Minimum 10 characters',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Optional fields
                  TextField(
                    controller: _summaryCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Clinical summary (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _historyCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Relevant history (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _medsCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Current medications (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _diagnosticsCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Diagnostic results (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Follow-up toggle
                  SwitchListTile(
                    value: _requiresFollowUp,
                    onChanged: (v) =>
                        setState(() => _requiresFollowUp = v),
                    title: const Text('Requires follow-up',
                        style: TextStyle(fontSize: 13)),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_requiresFollowUp) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now()
                              .add(const Duration(days: 7)),
                          firstDate: DateTime.now()
                              .add(const Duration(days: 1)),
                          lastDate: DateTime.now()
                              .add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => _followUpDate =
                              picked.toIso8601String());
                        }
                      },
                      icon: const Icon(Icons.event, size: 16),
                      label: Text(_followUpDate == null
                          ? 'Select follow-up date'
                          : _followUpDate!.split('T').first),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16,
                12 + MediaQuery.of(context).viewInsets.bottom),
            child: ElevatedButton(
              onPressed: (_isValid && !_submitting) ? _submit : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Send referral'),
            ),
          ),
        ],
      ),
    );
  }
}
