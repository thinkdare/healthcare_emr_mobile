import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/platform.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../data/providers/emergency_access_provider.dart';

/// TriggerEmergencyAccessScreen
///
/// Break-glass form. Immediately grants access to the patient without a prior
/// approval grant and creates an immutable audit log entry.
///
/// [prefillPatientId] — pre-populates the patient UUID (e.g. from patient
/// detail screen). When provided the field is locked and cannot be edited.
class TriggerEmergencyAccessScreen extends StatefulWidget {
  final String? prefillPatientId;
  final String? prefillPatientName;

  const TriggerEmergencyAccessScreen({
    super.key,
    this.prefillPatientId,
    this.prefillPatientName,
  });

  @override
  State<TriggerEmergencyAccessScreen> createState() =>
      _TriggerEmergencyAccessScreenState();
}

class _TriggerEmergencyAccessScreenState
    extends State<TriggerEmergencyAccessScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _patientIdCtrl;
  final _detailsCtrl = TextEditingController();

  String _emergencyType = 'life_threatening';
  bool _saving = false;

  static const _types = [
    ('life_threatening',  'Life Threatening'),
    ('unconscious',       'Unconscious Patient'),
    ('unable_to_consent', 'Unable to Consent'),
    ('critical_care',     'Critical Care'),
  ];

  @override
  void initState() {
    super.initState();
    _patientIdCtrl =
        TextEditingController(text: widget.prefillPatientId ?? '');
  }

  @override
  void dispose() {
    _patientIdCtrl.dispose();
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Confirmation dialog — break-glass is a high-stakes action
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded,
            color: AppTheme.errorColor, size: 36),
        title: const Text('Trigger Emergency Access?'),
        content: const Text(
          'This will immediately grant you access to the patient\'s record '
          'and create a permanent, immutable audit log entry.\n\n'
          'The patient\'s primary provider will be notified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm — Trigger Access'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);

    final data = <String, dynamic>{
      'master_patient_id': _patientIdCtrl.text.trim(),
      'emergency_type':    _emergencyType,
      'emergency_details': _detailsCtrl.text.trim(),
    };

    final provider = context.read<EmergencyAccessProvider>();
    final result = await provider.trigger(data);

    if (!mounted) return;
    setState(() => _saving = false);

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergency access granted. Primary provider notified.'),
          backgroundColor: AppTheme.warningColor,
          duration: Duration(seconds: 4),
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(provider.error ?? 'Request failed'),
        backgroundColor: AppTheme.errorColor,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.errorColor.withValues(alpha: 0.04),
      appBar: kIsIOS
          ? CupertinoNavigationBar(
              backgroundColor: AppTheme.errorColor.withValues(alpha: 0.9),
              middle: const Text('Emergency Access',
                  style: TextStyle(color: CupertinoColors.white)),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const CupertinoActivityIndicator()
                    : const Text('Submit',
                        style: TextStyle(color: CupertinoColors.white)),
              ),
            )
          : AppBar(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
              title: const Text('Break-Glass Emergency Access'),
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
              // Warning banner
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppTheme.errorColor.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: AppTheme.errorColor, size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Break-glass access bypasses normal approval '
                        'and is immediately granted. This action is '
                        'permanently logged and will be reviewed by '
                        'the primary provider.',
                        style: TextStyle(
                            color: AppTheme.errorColor,
                            fontWeight: FontWeight.w600,
                            height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),

              _sectionHeader('Patient'),
              if (widget.prefillPatientName != null) ...[
                _InfoRow(
                    label: 'Patient',
                    value: widget.prefillPatientName!),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _patientIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'Patient UUID *',
                  hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
                  prefixIcon: Icon(Icons.person_search),
                ),
                enabled: widget.prefillPatientId == null,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Patient UUID is required';
                  }
                  final uuidRe = RegExp(
                      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
                      caseSensitive: false);
                  if (!uuidRe.hasMatch(v.trim())) {
                    return 'Enter a valid patient UUID';
                  }
                  return null;
                },
              ),

              _sectionHeader('Emergency Type'),
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

              _sectionHeader('Justification'),
              TextFormField(
                controller: _detailsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Emergency details *',
                  hintText:
                      'Describe the emergency and why access is needed '
                      '(minimum 20 characters)…',
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                validator: (v) {
                  if (v == null || v.trim().length < 20) {
                    return 'Please describe the emergency (min. 20 characters)';
                  }
                  return null;
                },
              ),

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
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.errorColor)),
            const Divider(height: 8),
          ],
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14)),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
