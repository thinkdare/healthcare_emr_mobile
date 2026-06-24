// lib/presentation/patients/widgets/ward_request_sheets.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/platform.dart';
import '../../../data/models/ward_models.dart';
import '../../../data/providers/ward_workflow_provider.dart';

class RequestAdmissionSheet extends StatefulWidget {
  final String patientId;
  final List<WardModel> wards;
  final bool force;

  const RequestAdmissionSheet({
    super.key,
    required this.patientId,
    required this.wards,
    this.force = false,
  });

  @override
  State<RequestAdmissionSheet> createState() => _RequestAdmissionSheetState();
}

class _RequestAdmissionSheetState extends State<RequestAdmissionSheet> {
  final _reasonCtrl = TextEditingController();
  final _overrideCtrl = TextEditingController();
  WardModel? _ward;
  String _admissionType = 'elective';
  bool _submitting = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _overrideCtrl.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _ward != null &&
      _reasonCtrl.text.trim().isNotEmpty &&
      (!widget.force || _overrideCtrl.text.trim().isNotEmpty);

  Future<void> _submit() async {
    if (!_isValid) return;
    setState(() => _submitting = true);
    final provider = context.read<WardWorkflowProvider>();

    final ok = widget.force
        ? await provider.forceAdmit(
            widget.patientId,
            wardId: _ward!.id,
            admissionType: _admissionType,
            reason: _reasonCtrl.text.trim(),
            overrideReason: _overrideCtrl.text.trim(),
          )
        : await provider.requestAdmission(
            widget.patientId,
            wardId: _ward!.id,
            admissionType: _admissionType,
            reason: _reasonCtrl.text.trim(),
          );

    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.of(context).pop(true);
      showAdaptiveToast(context,
          widget.force ? 'Patient admitted' : 'Admission request submitted');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WardWorkflowProvider>();
    return _RequestSheetScaffold(
      title: widget.force ? 'Force Admit' : 'Request Admission',
      error: provider.error,
      submitting: _submitting,
      isValid: _isValid,
      onSubmit: _submit,
      submitLabel: widget.force ? 'Force admit' : 'Submit request',
      children: [
        _WardDropdown(
          wards: widget.wards,
          value: _ward,
          onChanged: (w) => setState(() => _ward = w),
        ),
        const SizedBox(height: 14),
        const Text('Admission type *',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'elective', label: Text('Elective')),
            ButtonSegment(value: 'emergency', label: Text('Emergency')),
          ],
          selected: {_admissionType},
          onSelectionChanged: (s) =>
              setState(() => _admissionType = s.first),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _reasonCtrl,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Reason *',
            border: OutlineInputBorder(),
          ),
        ),
        if (widget.force) ...[
          const SizedBox(height: 14),
          TextField(
            controller: _overrideCtrl,
            maxLines: 2,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Override reason *',
              hintText: 'Why this requires bypassing the normal request flow',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ],
    );
  }
}

class RequestTransferSheet extends StatefulWidget {
  final String patientId;
  final List<WardModel> wards;
  final bool force;

  const RequestTransferSheet({
    super.key,
    required this.patientId,
    required this.wards,
    this.force = false,
  });

  @override
  State<RequestTransferSheet> createState() => _RequestTransferSheetState();
}

class _RequestTransferSheetState extends State<RequestTransferSheet> {
  final _reasonCtrl = TextEditingController();
  final _overrideCtrl = TextEditingController();
  WardModel? _ward;
  bool _submitting = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _overrideCtrl.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _ward != null &&
      _reasonCtrl.text.trim().isNotEmpty &&
      (!widget.force || _overrideCtrl.text.trim().isNotEmpty);

  Future<void> _submit() async {
    if (!_isValid) return;
    setState(() => _submitting = true);
    final provider = context.read<WardWorkflowProvider>();

    final ok = widget.force
        ? await provider.forceTransfer(
            widget.patientId,
            toWardId: _ward!.id,
            reason: _reasonCtrl.text.trim(),
            overrideReason: _overrideCtrl.text.trim(),
          )
        : await provider.requestTransfer(
            widget.patientId,
            toWardId: _ward!.id,
            reason: _reasonCtrl.text.trim(),
          );

    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.of(context).pop(true);
      showAdaptiveToast(context,
          widget.force ? 'Patient transferred' : 'Transfer request submitted');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WardWorkflowProvider>();
    return _RequestSheetScaffold(
      title: widget.force ? 'Force Transfer' : 'Request Transfer',
      error: provider.error,
      submitting: _submitting,
      isValid: _isValid,
      onSubmit: _submit,
      submitLabel: widget.force ? 'Force transfer' : 'Submit request',
      children: [
        _WardDropdown(
          wards: widget.wards,
          value: _ward,
          onChanged: (w) => setState(() => _ward = w),
          label: 'Destination ward *',
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _reasonCtrl,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Reason *',
            border: OutlineInputBorder(),
          ),
        ),
        if (widget.force) ...[
          const SizedBox(height: 14),
          TextField(
            controller: _overrideCtrl,
            maxLines: 2,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Override reason *',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ],
    );
  }
}

class RequestDischargeSheet extends StatefulWidget {
  final String patientId;
  final bool force;

  const RequestDischargeSheet({
    super.key,
    required this.patientId,
    this.force = false,
  });

  @override
  State<RequestDischargeSheet> createState() => _RequestDischargeSheetState();
}

class _RequestDischargeSheetState extends State<RequestDischargeSheet> {
  final _summaryCtrl = TextEditingController();
  final _overrideCtrl = TextEditingController();
  String _dischargeType = 'routine';
  bool _submitting = false;

  static const _types = [
    ('routine', 'Routine'),
    ('against_medical_advice', 'Against Medical Advice'),
    ('deceased', 'Deceased'),
    ('transfer', 'Transfer'),
  ];

  @override
  void dispose() {
    _summaryCtrl.dispose();
    _overrideCtrl.dispose();
    super.dispose();
  }

  bool get _isValid => !widget.force || _overrideCtrl.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_isValid) return;
    setState(() => _submitting = true);
    final provider = context.read<WardWorkflowProvider>();

    final ok = widget.force
        ? await provider.forceDischarge(
            widget.patientId,
            dischargeType: _dischargeType,
            overrideReason: _overrideCtrl.text.trim(),
            dischargeSummary: _summaryCtrl.text.trim().isEmpty
                ? null
                : _summaryCtrl.text.trim(),
          )
        : await provider.requestDischarge(
            widget.patientId,
            dischargeType: _dischargeType,
            dischargeSummary: _summaryCtrl.text.trim().isEmpty
                ? null
                : _summaryCtrl.text.trim(),
          );

    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.of(context).pop(true);
      showAdaptiveToast(context,
          widget.force ? 'Patient discharged' : 'Discharge request initiated');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WardWorkflowProvider>();
    return _RequestSheetScaffold(
      title: widget.force ? 'Force Discharge' : 'Initiate Discharge',
      error: provider.error,
      submitting: _submitting,
      isValid: _isValid,
      onSubmit: _submit,
      submitLabel: widget.force ? 'Force discharge' : 'Initiate discharge',
      children: [
        const Text('Discharge type *',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        InputDecorator(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _dischargeType,
              isExpanded: true,
              items: _types
                  .map((t) =>
                      DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _dischargeType = v ?? 'routine'),
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _summaryCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Discharge summary (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        if (widget.force) ...[
          const SizedBox(height: 14),
          TextField(
            controller: _overrideCtrl,
            maxLines: 2,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Override reason *',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ],
    );
  }
}

/// Single-line reason prompt — used for reject / override-signoff actions.
Future<String?> showReasonPrompt(
  BuildContext context, {
  required String title,
  String label = 'Reason',
}) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLines: 3,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: ctrl.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(ctrl.text.trim()),
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
}

class _WardDropdown extends StatelessWidget {
  final List<WardModel> wards;
  final WardModel? value;
  final ValueChanged<WardModel?> onChanged;
  final String label;

  const _WardDropdown({
    required this.wards,
    required this.value,
    required this.onChanged,
    this.label = 'Ward *',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        InputDecorator(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<WardModel>(
              value: value,
              isExpanded: true,
              hint: const Text('Select ward'),
              items: wards
                  .map((w) => DropdownMenuItem(
                        value: w,
                        child: Text(
                            '${w.name} (${w.availableBedCount}/${w.bedCount} beds free)'),
                      ))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _RequestSheetScaffold extends StatelessWidget {
  final String title;
  final String? error;
  final bool submitting;
  final bool isValid;
  final VoidCallback onSubmit;
  final String submitLabel;
  final List<Widget> children;

  const _RequestSheetScaffold({
    required this.title,
    required this.error,
    required this.submitting,
    required this.isValid,
    required this.onSubmit,
    required this.submitLabel,
    required this.children,
  });

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
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 17)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (error != null)
            Container(
              color: Colors.red.shade50,
              padding: const EdgeInsets.all(12),
              child: Text(error!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
            ),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, 12 + MediaQuery.of(context).viewInsets.bottom),
            child: ElevatedButton(
              onPressed: (isValid && !submitting) ? onSubmit : null,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(submitLabel),
            ),
          ),
        ],
      ),
    );
  }
}
