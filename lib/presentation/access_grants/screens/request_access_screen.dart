import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/platform.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../data/providers/access_grant_provider.dart';

/// RequestAccessScreen
///
/// Form to request cross-facility access to a patient.
/// Can be pushed standalone (from AccessGrantsScreen FAB) with an optional
/// [prefillGlobalPatientId] for when the ID is already known (e.g. from a
/// patient detail screen).
class RequestAccessScreen extends StatefulWidget {
  final String? prefillGlobalPatientId;

  const RequestAccessScreen({super.key, this.prefillGlobalPatientId});

  @override
  State<RequestAccessScreen> createState() => _RequestAccessScreenState();
}

class _RequestAccessScreenState extends State<RequestAccessScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _patientIdCtrl;
  final _reasonCtrl = TextEditingController();

  String _accessLevel = 'view_only';
  final Set<String> _dataTypes = {};
  DateTime? _expiresAt;
  bool _saving = false;

  static const _accessLevels = [
    ('view_only',       'View only'),
    ('view_and_update', 'View & update'),
    ('full_access',     'Full access'),
  ];

  static const _allDataTypes = [
    ('demographics',    'Demographics'),
    ('medications',     'Medications'),
    ('allergies',       'Allergies'),
    ('lab_results',     'Lab results'),
    ('prescriptions',   'Prescriptions'),
    ('appointments',    'Appointments'),
    ('medical_history', 'Medical history'),
  ];

  @override
  void initState() {
    super.initState();
    _patientIdCtrl = TextEditingController(
        text: widget.prefillGlobalPatientId ?? '');
    // Default: select all data types
    for (final t in _allDataTypes) {
      _dataTypes.add(t.$1);
    }
  }

  @override
  void dispose() {
    _patientIdCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Access expires on',
    );
    if (picked != null) setState(() => _expiresAt = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final data = <String, dynamic>{
      'global_patient_id': _patientIdCtrl.text.trim(),
      'access_level':      _accessLevel,
      'reason':            _reasonCtrl.text.trim(),
      if (_dataTypes.isNotEmpty) 'data_types': _dataTypes.toList(),
      if (_expiresAt != null)
        'expires_at': '${_expiresAt!.year}-'
            '${_expiresAt!.month.toString().padLeft(2, '0')}-'
            '${_expiresAt!.day.toString().padLeft(2, '0')}',
    };

    final result =
        await context.read<AccessGrantProvider>().requestAccess(data);

    if (!mounted) return;
    setState(() => _saving = false);

    if (result != null) {
      final msg = result.autoApproved
          ? 'Access granted automatically.'
          : 'Access request submitted. Awaiting approval.';
      showAdaptiveToast(context, msg, type: ToastType.success);
      Navigator.of(context).pop(true);
    } else {
      showAdaptiveToast(
        context,
        context.read<AccessGrantProvider>().error ?? 'Request failed',
        type: ToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: kIsIOS
          ? CupertinoNavigationBar(
              middle: const Text('Request Patient Access'),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const CupertinoActivityIndicator()
                    : const Text('Submit'),
              ),
            )
          : AppBar(
              title: const Text('Request Patient Access'),
              actions: [
                TextButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.white)))
                      : const Text('Submit',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                ),
              ],
            ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info banner
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppTheme.primaryColor, size: 18),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Use this to request access to a patient being cared for '
                        'at another facility. The primary provider will review '
                        'your request.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

              _sectionHeader('Patient'),
              TextFormField(
                controller: _patientIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Global Patient ID *',
                  hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
                  prefixIcon: Icon(Icons.person_search),
                ),
                enabled: widget.prefillGlobalPatientId == null,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Patient ID is required';
                  }
                  // Basic UUID format check
                  final uuidRe = RegExp(
                      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
                      caseSensitive: false);
                  if (!uuidRe.hasMatch(v.trim())) {
                    return 'Enter a valid UUID (from patient records or referral)';
                  }
                  return null;
                },
              ),

              _sectionHeader('Access Level'),
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

              _sectionHeader('Data Types'),
              const Text(
                'Select which data you need access to:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _allDataTypes.map((t) {
                  final selected = _dataTypes.contains(t.$1);
                  return FilterChip(
                    label: Text(t.$2),
                    selected: selected,
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _dataTypes.add(t.$1);
                        } else {
                          _dataTypes.remove(t.$1);
                        }
                      });
                    },
                    selectedColor:
                        AppTheme.primaryColor.withValues(alpha: 0.15),
                    checkmarkColor: AppTheme.primaryColor,
                  );
                }).toList(),
              ),

              _sectionHeader('Request Details'),
              TextFormField(
                controller: _reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reason for access *',
                  hintText:
                      'Explain why you need access to this patient\'s records '
                      '(minimum 20 characters)…',
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                validator: (v) {
                  if (v == null || v.trim().length < 20) {
                    return 'Please provide a reason (min. 20 characters)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Expiry date
              InkWell(
                onTap: _pickExpiry,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Access expires (optional)',
                    suffixIcon: Icon(Icons.calendar_today, size: 18),
                  ),
                  child: Text(
                    _expiresAt != null
                        ? '${_expiresAt!.day.toString().padLeft(2, '0')}/'
                            '${_expiresAt!.month.toString().padLeft(2, '0')}/'
                            '${_expiresAt!.year}'
                        : 'No expiry (access until revoked)',
                    style: TextStyle(
                        color: _expiresAt != null ? null : AppTheme.gray600),
                  ),
                ),
              ),
              if (_expiresAt != null) ...[
                const SizedBox(height: 4),
                AdaptiveTextButton(
                  onPressed: () => setState(() => _expiresAt = null),
                  icon: const Icon(Icons.clear, size: 14),
                  child: const Text('Clear expiry date',
                      style: TextStyle(fontSize: 12)),
                ),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor)),
            const Divider(height: 8),
          ],
        ),
      );
}
