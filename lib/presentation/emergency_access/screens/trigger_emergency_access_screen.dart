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
  final _codeCtrl = TextEditingController();

  String _emergencyType = 'life_threatening';
  bool _saving = false;

  // Second factor: asked for when the form opens so an emailed code is already
  // waiting. null while requesting; see _requestCode.
  EmergencyAuthorization? _authorization;
  bool _requestingCode = false;
  String? _codeRequestError;

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestCode());
  }

  Future<void> _requestCode() async {
    if (!mounted) return;
    setState(() {
      _requestingCode = true;
      _codeRequestError = null;
    });
    final provider = context.read<EmergencyAccessProvider>();
    final result = await provider.requestAuthorization();
    if (!mounted) return;
    setState(() {
      _requestingCode = false;
      _authorization = result;
      _codeRequestError = result == null ? provider.error : null;
    });
  }

  @override
  void dispose() {
    _patientIdCtrl.dispose();
    _detailsCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Confirmation dialog — break-glass is a high-stakes action
    bool confirmed = false;
    await showAdaptiveActionSheet(
      context: context,
      title: 'Trigger Emergency Access?',
      message: 'This will immediately grant you access to the patient\'s record '
          'and create a permanent, immutable audit log entry.\n\n'
          'The patient\'s primary provider will be notified.',
      destructiveLabel: 'Confirm — Trigger Access',
      onConfirm: () => confirmed = true,
    );

    if (!confirmed || !mounted) return;

    setState(() => _saving = true);

    final data = <String, dynamic>{
      'master_patient_id': _patientIdCtrl.text.trim(),
      'emergency_type':    _emergencyType,
      'emergency_details': _detailsCtrl.text.trim(),
      'authorization_code': _codeCtrl.text.trim(),
    };

    final provider = context.read<EmergencyAccessProvider>();
    final result = await provider.trigger(data);

    if (!mounted) return;
    setState(() => _saving = false);

    if (result != null) {
      showAdaptiveToast(context, 'Emergency access granted. Primary provider notified.');
      Navigator.of(context).pop(true);
    } else {
      // An emailed code is single use and a TOTP code cannot be replayed, so a
      // failed attempt needs a fresh one.
      _codeCtrl.clear();
      showAdaptiveToast(context, provider.error ?? 'Request failed', type: ToastType.error);
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
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
              AdaptiveDropdown<String>(
                value: _emergencyType,
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

              _sectionHeader('Authorization'),
              _buildAuthorizationField(),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthorizationField() {
    final auth = _authorization;
    final String helper;
    if (_requestingCode) {
      helper = 'Requesting your authorization code…';
    } else if (_codeRequestError != null) {
      helper = _codeRequestError!;
    } else if (auth == null) {
      helper = 'Authorization code required.';
    } else if (auth.isTotp) {
      helper = 'Enter the code from your authenticator app, or an unused backup code.';
    } else {
      helper = 'A code was emailed to you. It expires in '
          '${auth.expiresInMinutes ?? 10} minutes and works once.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _codeCtrl,
          decoration: InputDecoration(
            labelText: 'Authorization code *',
            helperText: helper,
            helperMaxLines: 3,
            prefixIcon: const Icon(Icons.verified_user_outlined),
          ),
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.visiblePassword,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Enter the authorization code'
              : null,
        ),
        // Email codes can be re-sent; an authenticator needs no resend, but
        // the same button retries a failed request.
        if (!_requestingCode && (auth == null || !auth.isTotp))
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _saving ? null : _requestCode,
              child: Text(auth == null ? 'Try again' : 'Send a new code'),
            ),
          ),
      ],
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
