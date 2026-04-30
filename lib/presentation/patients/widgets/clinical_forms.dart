/// Clinical write forms — shown as modal bottom sheets from patient detail tabs.
///
/// AppointmentForm  — books a new appointment
/// PrescriptionForm — creates a new prescription (requires canPrescribe)
/// LabOrderForm     — creates a new lab order (requires canOrderLabs)
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../core/platform.dart';
import '../../../data/providers/clinical_provider.dart';

// ── Appointment Form ──────────────────────────────────────────────────────────

class AppointmentForm extends StatefulWidget {
  const AppointmentForm({super.key});

  @override
  State<AppointmentForm> createState() => _AppointmentFormState();
}

class _AppointmentFormState extends State<AppointmentForm> {
  final _formKey = GlobalKey<FormState>();

  DateTime? _appointmentDate;
  TimeOfDay? _appointmentTime;
  String _type = 'checkup';
  final _durationCtrl = TextEditingController(text: '30');
  final _reasonCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  static const _types = [
    ('checkup', 'Check-up'),
    ('followup', 'Follow-up'),
    ('emergency', 'Emergency'),
    ('consultation', 'Consultation'),
    ('procedure', 'Procedure'),
    ('vaccination', 'Vaccination'),
  ];

  @override
  void dispose() {
    _durationCtrl.dispose();
    _reasonCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _appointmentDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (time != null) setState(() => _appointmentTime = time);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_appointmentDate == null || _appointmentTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date and time')),
      );
      return;
    }

    setState(() => _saving = true);

    final dt = DateTime(
      _appointmentDate!.year, _appointmentDate!.month, _appointmentDate!.day,
      _appointmentTime!.hour, _appointmentTime!.minute,
    );

    final data = <String, dynamic>{
      'appointment_date': dt.toIso8601String(),
      'appointment_type': _type,
      'duration_minutes': int.tryParse(_durationCtrl.text) ?? 30,
      if (_reasonCtrl.text.trim().isNotEmpty) 'reason': _reasonCtrl.text.trim(),
      if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
    };

    final result = await context.read<ClinicalProvider>().createAppointment(data);
    if (!mounted) return;
    setState(() => _saving = false);

    if (result != null) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.read<ClinicalProvider>().error ?? 'Failed to book appointment'),
        backgroundColor: AppTheme.errorColor,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = _appointmentDate == null
        ? 'Select date'
        : '${_appointmentDate!.day}/${_appointmentDate!.month}/${_appointmentDate!.year}';
    final timeStr = _appointmentTime == null
        ? 'Select time'
        : _appointmentTime!.format(context);

    return _ModalSheet(
      title: 'Book Appointment',
      saving: _saving,
      onSave: _submit,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _DateButton(
                    label: 'Date',
                    value: dateStr,
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateButton(
                    label: 'Time',
                    value: timeStr,
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Appointment Type *'),
              items: _types
                  .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                  .toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _durationCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Duration (minutes)',
                  hintText: '30'),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 5 || n > 480) {
                  return 'Enter a duration between 5 and 480 minutes';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _reasonCtrl,
              decoration: const InputDecoration(labelText: 'Reason for visit'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Prescription Form ─────────────────────────────────────────────────────────

class PrescriptionForm extends StatefulWidget {
  const PrescriptionForm({super.key});

  @override
  State<PrescriptionForm> createState() => _PrescriptionFormState();
}

class _PrescriptionFormState extends State<PrescriptionForm> {
  final _formKey = GlobalKey<FormState>();

  final _medicationCtrl    = TextEditingController();
  final _dosageCtrl        = TextEditingController();
  final _frequencyCtrl     = TextEditingController();
  final _durationCtrl      = TextEditingController();
  final _quantityCtrl      = TextEditingController();
  final _refillsCtrl       = TextEditingController(text: '0');
  final _instructionsCtrl  = TextEditingController();

  String _route = 'oral';
  DateTime? _prescribedDate;
  DateTime? _expiresDate;
  bool _saving = false;

  static const _routes = [
    ('oral', 'Oral'),
    ('topical', 'Topical'),
    ('injection', 'Injection'),
    ('intravenous', 'Intravenous'),
    ('inhalation', 'Inhalation'),
    ('sublingual', 'Sublingual'),
    ('rectal', 'Rectal'),
    ('other', 'Other'),
  ];

  @override
  void dispose() {
    for (final c in [_medicationCtrl, _dosageCtrl, _frequencyCtrl,
        _durationCtrl, _quantityCtrl, _refillsCtrl, _instructionsCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  Future<void> _pickPrescribedDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) setState(() => _prescribedDate = d);
  }

  Future<void> _pickExpiresDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (d != null) setState(() => _expiresDate = d);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_prescribedDate == null || _expiresDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select prescribed and expiry dates')),
      );
      return;
    }

    setState(() => _saving = true);

    final data = <String, dynamic>{
      'medication_name':      _medicationCtrl.text.trim(),
      'dosage':               _dosageCtrl.text.trim(),
      'frequency':            _frequencyCtrl.text.trim(),
      'route':                _route,
      'duration_days':        int.tryParse(_durationCtrl.text) ?? 1,
      'quantity':             int.tryParse(_quantityCtrl.text) ?? 1,
      'refills_allowed':      int.tryParse(_refillsCtrl.text) ?? 0,
      'prescribed_date':      _fmt(_prescribedDate!),
      'expires_date':         _fmt(_expiresDate!),
      if (_instructionsCtrl.text.trim().isNotEmpty)
        'special_instructions': _instructionsCtrl.text.trim(),
    };

    final result = await context.read<ClinicalProvider>().createPrescription(data);
    if (!mounted) return;
    setState(() => _saving = false);

    if (result != null) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.read<ClinicalProvider>().error ?? 'Failed to create prescription'),
        backgroundColor: AppTheme.errorColor,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ModalSheet(
      title: 'New Prescription',
      saving: _saving,
      onSave: _submit,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _medicationCtrl,
              decoration: const InputDecoration(labelText: 'Medication Name *'),
              validator: _req('Medication name'),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _dosageCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Dosage *', hintText: 'e.g. 500mg'),
                  validator: _req('Dosage'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _frequencyCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Frequency *', hintText: 'e.g. twice daily'),
                  validator: _req('Frequency'),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _route,
              decoration: const InputDecoration(labelText: 'Route *'),
              items: _routes
                  .map((r) => DropdownMenuItem(value: r.$1, child: Text(r.$2)))
                  .toList(),
              onChanged: (v) => setState(() => _route = v!),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _durationCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Duration (days) *'),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n < 1) return 'Enter days';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _quantityCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity *'),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n < 1) return 'Enter quantity';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _refillsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Refills'),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _DateButton(
                  label: 'Prescribed Date *',
                  value: _prescribedDate != null
                      ? _fmt(_prescribedDate!)
                      : 'Select',
                  onTap: _pickPrescribedDate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateButton(
                  label: 'Expires *',
                  value: _expiresDate != null
                      ? _fmt(_expiresDate!)
                      : 'Select',
                  onTap: _pickExpiresDate,
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: _instructionsCtrl,
              decoration: const InputDecoration(
                  labelText: 'Special Instructions'),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Lab Order Form ────────────────────────────────────────────────────────────

class LabOrderForm extends StatefulWidget {
  const LabOrderForm({super.key});

  @override
  State<LabOrderForm> createState() => _LabOrderFormState();
}

class _LabOrderFormState extends State<LabOrderForm> {
  final _formKey = GlobalKey<FormState>();

  final _testNameCtrl = TextEditingController();
  final _testCodeCtrl = TextEditingController();
  final _notesCtrl    = TextEditingController();

  String _testType = 'blood';
  String _priority = 'routine';
  DateTime? _orderedDate;
  bool _saving = false;

  static const _testTypes = [
    ('blood', 'Blood'),
    ('urine', 'Urine'),
    ('stool', 'Stool'),
    ('imaging', 'Imaging'),
    ('biopsy', 'Biopsy'),
    ('culture', 'Culture'),
    ('other', 'Other'),
  ];

  static const _priorities = [
    ('routine', 'Routine'),
    ('urgent', 'Urgent'),
    ('stat', 'STAT'),
  ];

  @override
  void dispose() {
    _testNameCtrl.dispose();
    _testCodeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (d != null) setState(() => _orderedDate = d);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_orderedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an ordered date')),
      );
      return;
    }

    setState(() => _saving = true);

    final data = <String, dynamic>{
      'test_name':    _testNameCtrl.text.trim(),
      'test_type':    _testType,
      'priority':     _priority,
      'ordered_date': _fmt(_orderedDate!),
      if (_testCodeCtrl.text.trim().isNotEmpty)
        'test_code': _testCodeCtrl.text.trim(),
      if (_notesCtrl.text.trim().isNotEmpty)
        'notes': _notesCtrl.text.trim(),
    };

    final result = await context.read<ClinicalProvider>().createLabOrder(data);
    if (!mounted) return;
    setState(() => _saving = false);

    if (result != null) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.read<ClinicalProvider>().error ?? 'Failed to create lab order'),
        backgroundColor: AppTheme.errorColor,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ModalSheet(
      title: 'New Lab Order',
      saving: _saving,
      onSave: _submit,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _testNameCtrl,
              decoration: const InputDecoration(labelText: 'Test Name *'),
              validator: _req('Test name'),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _testType,
                  decoration: const InputDecoration(labelText: 'Test Type *'),
                  items: _testTypes
                      .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                      .toList(),
                  onChanged: (v) => setState(() => _testType = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: _priorities
                      .map((p) => DropdownMenuItem(value: p.$1, child: Text(p.$2)))
                      .toList(),
                  onChanged: (v) => setState(() => _priority = v!),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: _testCodeCtrl,
              decoration: const InputDecoration(
                  labelText: 'Test Code', hintText: 'Optional'),
            ),
            const SizedBox(height: 12),
            _DateButton(
              label: 'Ordered Date *',
              value: _orderedDate != null ? _fmt(_orderedDate!) : 'Select date',
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Clinical notes'),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Document Upload Form ──────────────────────────────────────────────────────

class DocumentUploadForm extends StatefulWidget {
  const DocumentUploadForm({super.key});

  @override
  State<DocumentUploadForm> createState() => _DocumentUploadFormState();
}

class _DocumentUploadFormState extends State<DocumentUploadForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _documentType = 'clinical_note';
  bool _isConfidential = false;
  PlatformFile? _pickedFile;
  bool _saving = false;

  static const _types = [
    ('lab_report', 'Lab Report'),
    ('imaging', 'Imaging'),
    ('referral_letter', 'Referral Letter'),
    ('discharge_summary', 'Discharge Summary'),
    ('consent_form', 'Consent Form'),
    ('prescription', 'Prescription'),
    ('clinical_note', 'Clinical Note'),
    ('insurance', 'Insurance'),
    ('other', 'Other'),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'tiff', 'txt', 'zip'],
      withData: false,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.single;
      setState(() => _pickedFile = file);
      if (_titleCtrl.text.isEmpty) {
        final name = file.name;
        final dotIdx = name.lastIndexOf('.');
        _titleCtrl.text = dotIdx > 0 ? name.substring(0, dotIdx) : name;
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file to upload')),
      );
      return;
    }
    if (_pickedFile!.path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read file path')),
      );
      return;
    }

    setState(() => _saving = true);

    final result = await context.read<ClinicalProvider>().uploadDocument(
          filePath: _pickedFile!.path!,
          fileName: _pickedFile!.name,
          title: _titleCtrl.text.trim(),
          documentType: _documentType,
          notes: _notesCtrl.text.trim().isNotEmpty
              ? _notesCtrl.text.trim()
              : null,
          isConfidential: _isConfidential,
        );

    if (!mounted) return;
    setState(() => _saving = false);

    if (result != null) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.read<ClinicalProvider>().error ?? 'Upload failed'),
        backgroundColor: AppTheme.errorColor,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ModalSheet(
      title: 'Upload Document',
      saving: _saving,
      onSave: _submit,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File picker button
            InkWell(
              onTap: _saving ? null : _pickFile,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _pickedFile != null
                        ? AppTheme.primaryColor
                        : AppTheme.gray600.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _pickedFile != null
                          ? Icons.insert_drive_file
                          : Icons.upload_file,
                      color: _pickedFile != null
                          ? AppTheme.primaryColor
                          : AppTheme.gray600,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _pickedFile != null
                            ? _pickedFile!.name
                            : 'Select file  (PDF, image, ZIP, text)',
                        style: TextStyle(
                          color: _pickedFile != null ? null : AppTheme.gray600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_pickedFile != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        _formatSize(_pickedFile!.size),
                        style:
                            TextStyle(fontSize: 12, color: AppTheme.gray600),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Title *'),
              validator: _req('Title'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _documentType,
              decoration: const InputDecoration(labelText: 'Document Type *'),
              items: _types
                  .map((t) =>
                      DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                  .toList(),
              onChanged: (v) => setState(() => _documentType = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 3,
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Confidential', style: TextStyle(fontSize: 14)),
              subtitle: Text(
                'Only visible to primary provider',
                style: TextStyle(fontSize: 12, color: AppTheme.gray600),
              ),
              value: _isConfidential,
              onChanged: (v) => setState(() => _isConfidential = v),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _ModalSheet extends StatelessWidget {
  final String title;
  final bool saving;
  final VoidCallback onSave;
  final Widget child;

  const _ModalSheet({
    required this.title,
    required this.saving,
    required this.onSave,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.gray600.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            child,

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: AdaptiveFilledButton(
                onPressed: saving ? null : onSave,
                child: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white)))
                    : Text(title),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateButton(
      {required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(value,
            style: TextStyle(
                color: value.startsWith('Select')
                    ? AppTheme.gray600
                    : null)),
      ),
    );
  }
}

String? Function(String?) _req(String field) =>
    (v) => (v == null || v.trim().isEmpty) ? '$field is required' : null;
