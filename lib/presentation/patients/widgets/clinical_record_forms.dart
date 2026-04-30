// lib/presentation/patients/widgets/clinical_record_forms.dart
//
// Write forms for the five new clinical record resources, shown as modal
// bottom sheets from the Clinical Record tab FAB.
//
// VitalSignForm    — records a set of vital signs
// DiagnosisForm    — records a new diagnosis
// ProblemForm      — adds an entry to the problem list
// ProcedureForm    — records a procedure
// ImmunizationForm — records a vaccine administration
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/platform.dart';
import '../../../data/providers/clinical_provider.dart';

// ── Shared helpers ────────────────────────────────────────────────────────────

Widget _sheet({required String title, required Widget child}) {
  return Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(title,
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}

InputDecoration _field(String label, {String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );

Widget _saveButton(bool saving, VoidCallback onPressed, String label) {
  return SizedBox(
    width: double.infinity,
    child: AdaptiveFilledButton(
      onPressed: saving ? null : onPressed,
      child: saving
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
          : Text(label),
    ),
  );
}

// ── VitalSignForm ─────────────────────────────────────────────────────────────

class VitalSignForm extends StatefulWidget {
  const VitalSignForm({super.key});

  @override
  State<VitalSignForm> createState() => _VitalSignFormState();
}

class _VitalSignFormState extends State<VitalSignForm> {
  final _formKey = GlobalKey<FormState>();
  final _bpSysCtrl  = TextEditingController();
  final _bpDiaCtrl  = TextEditingController();
  final _hrCtrl     = TextEditingController();
  final _rrCtrl     = TextEditingController();
  final _tempCtrl   = TextEditingController();
  final _spo2Ctrl   = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _notesCtrl  = TextEditingController();
  String _tempUnit   = 'C';
  String _weightUnit = 'kg';
  String _heightUnit = 'cm';
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _bpSysCtrl, _bpDiaCtrl, _hrCtrl, _rrCtrl, _tempCtrl,
      _spo2Ctrl, _weightCtrl, _heightCtrl, _notesCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _unitToggle(String current, List<String> options,
      ValueChanged<String> onChanged) {
    return ToggleButtons(
      isSelected: options.map((o) => o == current).toList(),
      onPressed: (i) => setState(() => onChanged(options[i])),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
      children: options
          .map((o) => Text(o, style: const TextStyle(fontSize: 12)))
          .toList(),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    int? toInt(TextEditingController c) =>
        c.text.trim().isEmpty ? null : int.tryParse(c.text.trim());
    double? toDbl(TextEditingController c) =>
        c.text.trim().isEmpty ? null : double.tryParse(c.text.trim());

    final data = <String, dynamic>{
      'recorded_at': DateTime.now().toIso8601String(),
      if (_bpSysCtrl.text.trim().isNotEmpty)
        'blood_pressure_systolic': toInt(_bpSysCtrl),
      if (_bpDiaCtrl.text.trim().isNotEmpty)
        'blood_pressure_diastolic': toInt(_bpDiaCtrl),
      if (_hrCtrl.text.trim().isNotEmpty) 'heart_rate': toInt(_hrCtrl),
      if (_rrCtrl.text.trim().isNotEmpty) 'respiratory_rate': toInt(_rrCtrl),
      if (_tempCtrl.text.trim().isNotEmpty) ...{
        'temperature': toDbl(_tempCtrl),
        'temperature_unit': _tempUnit,
      },
      if (_spo2Ctrl.text.trim().isNotEmpty)
        'oxygen_saturation': toDbl(_spo2Ctrl),
      if (_weightCtrl.text.trim().isNotEmpty) ...{
        'weight': toDbl(_weightCtrl),
        'weight_unit': _weightUnit,
      },
      if (_heightCtrl.text.trim().isNotEmpty) ...{
        'height': toDbl(_heightCtrl),
        'height_unit': _heightUnit,
      },
      if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
    };

    final result =
        await context.read<ClinicalProvider>().createVitalSign(data);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result != null) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _sheet(
        title: 'Record Vital Signs',
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _bpSysCtrl,
                    decoration: _field('Systolic BP', hint: 'mmHg'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _bpDiaCtrl,
                    decoration: _field('Diastolic BP', hint: 'mmHg'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _hrCtrl,
                    decoration: _field('Heart Rate', hint: 'bpm'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _rrCtrl,
                    decoration: _field('Resp. Rate', hint: '/min'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _tempCtrl,
                    decoration: _field('Temperature'),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                  ),
                ),
                const SizedBox(width: 8),
                _unitToggle(
                    _tempUnit, ['C', 'F'], (v) => _tempUnit = v),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                controller: _spo2Ctrl,
                decoration: _field('Oxygen Saturation', hint: '%'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _weightCtrl,
                    decoration: _field('Weight'),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                  ),
                ),
                const SizedBox(width: 8),
                _unitToggle(
                    _weightUnit, ['kg', 'lbs'], (v) => _weightUnit = v),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _heightCtrl,
                    decoration: _field('Height'),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                  ),
                ),
                const SizedBox(width: 8),
                _unitToggle(
                    _heightUnit, ['cm', 'in'], (v) => _heightUnit = v),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: _field('Notes'),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              _saveButton(_saving, _save, 'Save Vitals'),
            ],
          ),
        ),
      ),
    );
  }
}

// ── DiagnosisForm ─────────────────────────────────────────────────────────────

class DiagnosisForm extends StatefulWidget {
  const DiagnosisForm({super.key});

  @override
  State<DiagnosisForm> createState() => _DiagnosisFormState();
}

class _DiagnosisFormState extends State<DiagnosisForm> {
  final _formKey   = GlobalKey<FormState>();
  final _descCtrl  = TextEditingController();
  final _icdCtrl   = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _type   = 'primary';
  String _status = 'active';
  bool _saving   = false;

  static const _types = [
    ('primary', 'Primary'),
    ('secondary', 'Secondary'),
    ('differential', 'Differential'),
    ('comorbidity', 'Comorbidity'),
  ];

  static const _statuses = [
    ('active', 'Active'),
    ('in_remission', 'In Remission'),
    ('resolved', 'Resolved'),
    ('ruled_out', 'Ruled Out'),
  ];

  @override
  void dispose() {
    _descCtrl.dispose();
    _icdCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final data = {
      'description': _descCtrl.text.trim(),
      'diagnosis_type': _type,
      'status': _status,
      if (_icdCtrl.text.trim().isNotEmpty) 'icd_code': _icdCtrl.text.trim(),
      if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
    };

    final result =
        await context.read<ClinicalProvider>().createDiagnosis(data);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result != null) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _sheet(
        title: 'Record Diagnosis',
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _descCtrl,
                decoration: _field('Description *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _icdCtrl,
                decoration: _field('ICD Code', hint: 'e.g. E11.9'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: _field('Diagnosis Type'),
                items: _types
                    .map((t) => DropdownMenuItem(
                        value: t.$1, child: Text(t.$2)))
                    .toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: _field('Status'),
                items: _statuses
                    .map((s) => DropdownMenuItem(
                        value: s.$1, child: Text(s.$2)))
                    .toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: _field('Notes'),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              _saveButton(_saving, _save, 'Save Diagnosis'),
            ],
          ),
        ),
      ),
    );
  }
}

// ── ProblemForm ───────────────────────────────────────────────────────────────

class ProblemForm extends StatefulWidget {
  const ProblemForm({super.key});

  @override
  State<ProblemForm> createState() => _ProblemFormState();
}

class _ProblemFormState extends State<ProblemForm> {
  final _formKey   = GlobalKey<FormState>();
  final _descCtrl  = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _status = 'active';
  bool _saving   = false;

  static const _statuses = [
    ('active', 'Active'),
    ('chronic', 'Chronic'),
    ('in_remission', 'In Remission'),
    ('resolved', 'Resolved'),
  ];

  @override
  void dispose() {
    _descCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final data = {
      'description': _descCtrl.text.trim(),
      'status': _status,
      if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
    };

    final result =
        await context.read<ClinicalProvider>().createProblem(data);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result != null) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _sheet(
        title: 'Add to Problem List',
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _descCtrl,
                decoration: _field('Problem Description *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: _field('Status'),
                items: _statuses
                    .map((s) => DropdownMenuItem(
                        value: s.$1, child: Text(s.$2)))
                    .toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: _field('Notes'),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              _saveButton(_saving, _save, 'Add Problem'),
            ],
          ),
        ),
      ),
    );
  }
}

// ── ProcedureForm ─────────────────────────────────────────────────────────────

class ProcedureForm extends StatefulWidget {
  const ProcedureForm({super.key});

  @override
  State<ProcedureForm> createState() => _ProcedureFormState();
}

class _ProcedureFormState extends State<ProcedureForm> {
  final _formKey      = GlobalKey<FormState>();
  final _descCtrl     = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _notesCtrl    = TextEditingController();
  String _status = 'planned';
  bool _saving   = false;

  static const _statuses = [
    ('planned', 'Planned'),
    ('in_progress', 'In Progress'),
    ('completed', 'Completed'),
    ('cancelled', 'Cancelled'),
  ];

  @override
  void dispose() {
    _descCtrl.dispose();
    _durationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final data = <String, dynamic>{
      'description': _descCtrl.text.trim(),
      'status': _status,
      'performed_at': DateTime.now().toIso8601String(),
      if (_durationCtrl.text.trim().isNotEmpty)
        'duration_minutes': int.tryParse(_durationCtrl.text.trim()),
      if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
    };

    final result =
        await context.read<ClinicalProvider>().createProcedure(data);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result != null) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _sheet(
        title: 'Record Procedure',
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _descCtrl,
                decoration: _field('Description *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: _field('Status'),
                items: _statuses
                    .map((s) => DropdownMenuItem(
                        value: s.$1, child: Text(s.$2)))
                    .toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _durationCtrl,
                decoration: _field('Duration (minutes)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: _field('Notes'),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              _saveButton(_saving, _save, 'Save Procedure'),
            ],
          ),
        ),
      ),
    );
  }
}

// ── ImmunizationForm ──────────────────────────────────────────────────────────

class ImmunizationForm extends StatefulWidget {
  const ImmunizationForm({super.key});

  @override
  State<ImmunizationForm> createState() => _ImmunizationFormState();
}

class _ImmunizationFormState extends State<ImmunizationForm> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _codeCtrl  = TextEditingController();
  final _doseCtrl  = TextEditingController(text: '1');
  final _lotCtrl   = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _route = 'intramuscular';
  bool _saving  = false;

  static const _routes = [
    ('intramuscular', 'Intramuscular'),
    ('subcutaneous', 'Subcutaneous'),
    ('intradermal', 'Intradermal'),
    ('oral', 'Oral'),
    ('nasal', 'Nasal'),
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _doseCtrl.dispose();
    _lotCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final data = <String, dynamic>{
      'vaccine_name': _nameCtrl.text.trim(),
      'vaccine_code': _codeCtrl.text.trim(),
      'dose_number': int.tryParse(_doseCtrl.text.trim()) ?? 1,
      'route': _route,
      'administered_at': DateTime.now().toIso8601String(),
      if (_lotCtrl.text.trim().isNotEmpty) 'lot_number': _lotCtrl.text.trim(),
      if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
    };

    final result =
        await context.read<ClinicalProvider>().createImmunization(data);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result != null) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _sheet(
        title: 'Record Immunization',
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: _field('Vaccine Name *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _codeCtrl,
                decoration: _field('CVX Code *', hint: 'e.g. 140'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _doseCtrl,
                    decoration: _field('Dose #'),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        (v == null || int.tryParse(v) == null)
                            ? 'Enter a number'
                            : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _lotCtrl,
                    decoration: _field('Lot Number'),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _route,
                decoration: _field('Route'),
                items: _routes
                    .map((r) => DropdownMenuItem(
                        value: r.$1, child: Text(r.$2)))
                    .toList(),
                onChanged: (v) => setState(() => _route = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: _field('Notes'),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              _saveButton(_saving, _save, 'Record Vaccination'),
            ],
          ),
        ),
      ),
    );
  }
}
