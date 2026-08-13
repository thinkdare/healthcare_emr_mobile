import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/platform.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/emergency_access_provider.dart';
import '../../../config/app_colors.dart';

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
    ('life_threatening', 'Life Threatening'),
    ('unconscious', 'Unconscious Patient'),
    ('unable_to_consent', 'Unable to Consent'),
    ('critical_care', 'Critical Care'),
  ];

  @override
  void initState() {
    super.initState();
    _patientIdCtrl = TextEditingController(text: widget.prefillPatientId ?? '');
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
    bool confirmed = false;
    await showAdaptiveActionSheet(
      context: context,
      title: 'Trigger Emergency Access?',
      message:
          'This will immediately grant you access to the patient\'s record '
          'and create a permanent, immutable audit log entry.\n\n'
          'The patient\'s primary provider will be notified.',
      destructiveLabel: 'Confirm — Trigger Access',
      onConfirm: () => confirmed = true,
    );

    if (!confirmed || !mounted) return;

    setState(() => _saving = true);

    final data = <String, dynamic>{
      'master_patient_id': _patientIdCtrl.text.trim(),
      'emergency_type': _emergencyType,
      'emergency_details': _detailsCtrl.text.trim(),
    };

    final provider = context.read<EmergencyAccessProvider>();
    final result = await provider.trigger(data);

    if (!mounted) return;
    setState(() => _saving = false);

    if (result != null) {
      showAdaptiveToast(
        context,
        'Emergency access granted. Primary provider notified.',
      );
      Navigator.of(context).pop(true);
    } else {
      showAdaptiveToast(
        context,
        provider.error ?? 'Request failed',
        type: ToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).critical.withValues(alpha: 0.04),
      appBar: kIsIOS
          ? CupertinoNavigationBar(
              backgroundColor: AppColors.of(
                context,
              ).critical.withValues(alpha: 0.9),
              middle: Text(
                'Emergency Access',
                style: TextStyle(color: AppColors.of(context).onCritical),
              ),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const CupertinoActivityIndicator()
                    : Text(
                        'Submit',
                        style: TextStyle(color: AppColors.of(context).onCritical),
                      ),
              ),
            )
          : AppBar(
              backgroundColor: AppColors.of(context).critical,
              foregroundColor: AppColors.of(context).onCritical,
              title: const Text('Break-Glass Emergency Access'),
              actions: [
                TextButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                                AppColors.of(context).onCritical),
                          ),
                        )
                      : Text(
                          'Submit',
                          style: TextStyle(
                            color: AppColors.of(context).onCritical,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                  color: AppColors.of(context).critical.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.of(
                      context,
                    ).critical.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.of(context).critical,
                      size: 22,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Break-glass access bypasses normal approval '
                        'and is immediately granted. This action is '
                        'permanently logged and will be reviewed by '
                        'the primary provider.',
                        style: TextStyle(
                          color: AppColors.of(context).critical,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              _sectionHeader('Patient'),
              if (widget.prefillPatientName != null) ...[
                _InfoRow(label: 'Patient', value: widget.prefillPatientName!),
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
                    caseSensitive: false,
                  );
                  if (!uuidRe.hasMatch(v.trim())) {
                    return 'Enter a valid patient UUID';
                  }
                  return null;
                },
              ),

              _sectionHeader('Emergency Type'),
              AdaptiveDropdown<String>(
                value: _emergencyType,
                decoration: const InputDecoration(
                  labelText: 'Emergency Type *',
                ),
                items: _types
                    .map(
                      (t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)),
                    )
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
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.of(context).critical,
          ),
        ),
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
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
