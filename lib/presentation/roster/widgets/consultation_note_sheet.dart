// lib/presentation/roster/widgets/consultation_note_sheet.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/intra_grant_provider.dart';

/// Bottom sheet for writing a structured consultation note.
///
/// Formats four optional fields (diagnosis, medications, tests, general notes)
/// into a single readable body and saves as a ClinicalNote via POST /patients/{id}/notes.
/// Existing patient records are never modified.
Future<bool> showConsultationNoteSheet(
    BuildContext context, String patientId) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _ConsultationNoteSheet(patientId: patientId),
  );
  return result == true;
}

class _ConsultationNoteSheet extends StatefulWidget {
  final String patientId;
  const _ConsultationNoteSheet({required this.patientId});

  @override
  State<_ConsultationNoteSheet> createState() => _ConsultationNoteSheetState();
}

class _ConsultationNoteSheetState extends State<_ConsultationNoteSheet> {
  final _diagnosisCtrl    = TextEditingController();
  final _medsCtrl         = TextEditingController();
  final _testsCtrl        = TextEditingController();
  final _additionalCtrl   = TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _diagnosisCtrl.dispose();
    _medsCtrl.dispose();
    _testsCtrl.dispose();
    _additionalCtrl.dispose();
    super.dispose();
  }

  bool get _hasContent =>
      _diagnosisCtrl.text.trim().isNotEmpty ||
      _medsCtrl.text.trim().isNotEmpty ||
      _testsCtrl.text.trim().isNotEmpty ||
      _additionalCtrl.text.trim().isNotEmpty;

  String _buildBody() {
    final buf = StringBuffer();

    void section(String heading, String content) {
      if (content.isEmpty) return;
      if (buf.isNotEmpty) buf.write('\n\n');
      buf.writeln(heading.toUpperCase());
      buf.write(content);
    }

    section('Diagnosis', _diagnosisCtrl.text.trim());
    section('Medications prescribed', _medsCtrl.text.trim());
    section('Tests ordered', _testsCtrl.text.trim());
    section('Additional notes', _additionalCtrl.text.trim());

    return buf.toString();
  }

  String _buildTitle() {
    final now = DateTime.now();
    return 'Consultation — '
        '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/'
        '${now.year}';
  }

  Future<void> _save() async {
    if (!_hasContent) return;
    setState(() {
      _saving = true;
      _error  = null;
    });

    try {
      final repo = context.read<IntraGrantProvider>().repository;
      await repo.createNote(
        widget.patientId,
        title: _buildTitle(),
        body:  _buildBody(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error  = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Handle
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
                  child: Text('Consultation Note',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 17)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),
          // Read-only notice
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This note is appended to the patient record. '
                    'Existing records cannot be altered.',
                    style: TextStyle(
                        fontSize: 12, color: Colors.blue.shade700),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      size: 16, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                        style: TextStyle(
                            fontSize: 12, color: Colors.red.shade700)),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _error = null),
                    child: Icon(Icons.close,
                        size: 16, color: Colors.red.shade700),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _NoteField(
                    controller: _diagnosisCtrl,
                    label: 'Diagnosis',
                    hint: 'e.g. Hypertensive urgency, Type 2 diabetes mellitus',
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  _NoteField(
                    controller: _medsCtrl,
                    label: 'Medications prescribed',
                    hint: 'e.g. Amlodipine 10 mg OD, Metformin 500 mg BD',
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  _NoteField(
                    controller: _testsCtrl,
                    label: 'Tests ordered',
                    hint: 'e.g. FBC, U&E, fasting blood sugar, ECG',
                    maxLines: 2,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  _NoteField(
                    controller: _additionalCtrl,
                    label: 'Additional notes',
                    hint: 'Any other observations, instructions, or follow-up plan',
                    maxLines: 4,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          Padding(
            padding:
                EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
            child: ElevatedButton(
              onPressed: (_hasContent && !_saving) ? _save : null,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save note'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final ValueChanged<String> onChanged;

  const _NoteField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.maxLines,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }
}
