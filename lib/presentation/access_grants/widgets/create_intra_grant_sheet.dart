// lib/presentation/access_grants/widgets/create_intra_grant_sheet.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/platform.dart';
import '../../../data/models/patient_models.dart';
import '../../../data/providers/intra_grant_provider.dart';
import '../../../data/repositories/facility_repository.dart';

class CreateIntraGrantSheet extends StatefulWidget {
  /// When launched from PatientDetailScreen the patient is pre-filled.
  final PatientModel? patient;

  const CreateIntraGrantSheet({super.key, this.patient});

  @override
  State<CreateIntraGrantSheet> createState() => _CreateIntraGrantSheetState();
}

class _CreateIntraGrantSheetState extends State<CreateIntraGrantSheet> {
  final _questionCtrl = TextEditingController();

  Map<String, dynamic>? _selectedColleague;
  List<Map<String, dynamic>> _colleagues = [];
  bool _loadingColleagues = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadColleagues();
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadColleagues() async {
    setState(() => _loadingColleagues = true);
    try {
      final apiClient = context.read<IntraGrantProvider>().repository.apiClient;
      final repo = FacilityRepository(apiClient: apiClient);
      // listStaffAtTenant with current tenant — the API will scope to logged-in user's tenant
      final staff = await repo.listStaffAtCurrentTenant();
      setState(() => _colleagues = staff);
    } catch (_) {
      setState(() => _error = 'Failed to load colleagues.');
    } finally {
      setState(() => _loadingColleagues = false);
    }
  }

  bool get _isValid =>
      widget.patient != null &&
      _selectedColleague != null &&
      _questionCtrl.text.trim().length >= 10;

  Future<void> _submit() async {
    if (!_isValid) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final data = {
      'patient_id':               widget.patient!.id,
      'granted_to_membership_id': _selectedColleague!['membership_id'] as String,
      'access_level':             'view_only',
      'question':                 _questionCtrl.text.trim(),
    };

    final provider = context.read<IntraGrantProvider>();
    final created = await provider.create(data);
    if (!mounted) return;

    setState(() => _submitting = false);

    if (created != null) {
      Navigator.of(context).pop(true);
      showAdaptiveToast(context, 'Consultation request sent.');
    } else {
      setState(() => _error = provider.error ?? 'Failed to send request.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
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
                  child: Text('Ask a Colleague',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 17)),
                ),
                if (widget.patient != null)
                  Text(widget.patient!.fullName,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_error != null)
            Container(
              color: Colors.red.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      size: 16, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                        style: TextStyle(
                            color: Colors.red.shade700, fontSize: 12)),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _error = null),
                    child: Icon(Icons.close,
                        size: 16, color: Colors.red.shade700),
                  ),
                ],
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Patient info (read-only when pre-filled)
                  if (widget.patient != null) ...[
                    _SectionLabel('Patient'),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline,
                              size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.patient!.fullName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                                if (widget.patient!.mrn != null)
                                  Text('MRN: ${widget.patient!.mrn}',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Colleague picker
                  _SectionLabel('Ask colleague *'),
                  const SizedBox(height: 6),
                  _loadingColleagues
                      ? const Center(child: CircularProgressIndicator())
                      : InputDecorator(
                          decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<Map<String, dynamic>>(
                              value: _selectedColleague,
                              isExpanded: true,
                              hint: const Text('Select a colleague'),
                              items: _colleagues
                                  .map((c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(
                                            '${c['name'] ?? ''}  •  ${c['staff_type'] ?? ''}'),
                                      ))
                                  .toList(),
                              onChanged: (c) =>
                                  setState(() => _selectedColleague = c),
                            ),
                          ),
                        ),
                  const SizedBox(height: 16),
                  // Question
                  TextField(
                    controller: _questionCtrl,
                    maxLines: 5,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Clinical question *',
                      hintText:
                          'e.g. Patient presenting with chest pain, currently on 5 mg bisoprolol — safe to increase given the attached digoxin level?',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_questionCtrl.text.trim().length}/2000  (min 10 characters)',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    textAlign: TextAlign.right,
                  ),
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
                  : const Text('Send consultation request'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black87),
      );
}
