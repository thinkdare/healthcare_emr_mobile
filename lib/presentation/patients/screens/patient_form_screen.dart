import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../core/platform.dart';
import '../../../data/models/patient_models.dart';
import '../../../data/providers/patient_provider.dart';

/// Patient create / edit form.
///
/// Pass [patient] to edit an existing record; omit for new patient creation.
class PatientFormScreen extends StatefulWidget {
  final PatientModel? patient;

  const PatientFormScreen({super.key, this.patient});

  bool get isEditing => patient != null;

  @override
  State<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends State<PatientFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Basic info
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _dob;         // yyyy-MM-dd
  String _gender = 'male';
  String? _bloodType;

  // Contact
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;

  // Emergency contact
  late final TextEditingController _emergencyName;
  late final TextEditingController _emergencyPhone;

  // Medical arrays
  final List<Map<String, String>> _allergies = [];       // {name, severity}
  final List<Map<String, String>> _medications = [];     // {name, dosage}
  final List<String> _conditions = [];

  // Insurance
  late final TextEditingController _insuranceProvider;
  late final TextEditingController _insuranceNumber;

  // Medical history
  late final TextEditingController _medicalHistory;

  bool _saving = false;

  static const _genders = [
    ('male', 'Male'),
    ('female', 'Female'),
    ('other', 'Other'),
    ('prefer_not_to_say', 'Prefer not to say'),
  ];

  static const _bloodTypes = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
  ];

  static const _severities = [
    ('mild', 'Mild'),
    ('moderate', 'Moderate'),
    ('severe', 'Severe'),
    ('life_threatening', 'Life-threatening'),
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.patient;
    _firstName = TextEditingController(text: p?.firstName ?? '');
    _lastName  = TextEditingController(text: p?.lastName ?? '');
    _dob       = TextEditingController(text: p?.dateOfBirth ?? '');
    _gender    = p?.gender ?? 'male';
    _bloodType = p?.bloodType;

    _phone   = TextEditingController(text: p?.phone ?? '');
    _email   = TextEditingController(text: p?.email ?? '');
    _address = TextEditingController(text: p?.address ?? '');

    _emergencyName  = TextEditingController(text: p?.emergencyContactName ?? '');
    _emergencyPhone = TextEditingController(text: p?.emergencyContactPhone ?? '');

    _insuranceProvider = TextEditingController(text: p?.insuranceProvider ?? '');
    _insuranceNumber   = TextEditingController(text: p?.insuranceNumber ?? '');
    _medicalHistory    = TextEditingController(text: p?.medicalHistory ?? '');

    if (p != null) {
      _allergies.addAll(p.allergies.map(
          (a) => {'name': a.name, 'severity': a.severity}));
      _medications.addAll(p.currentMedications.map(
          (m) => {'name': m.name, 'dosage': m.dosage ?? ''}));
      _conditions.addAll(p.chronicConditions);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _firstName, _lastName, _dob, _phone, _email, _address,
      _emergencyName, _emergencyPhone, _insuranceProvider, _insuranceNumber,
      _medicalHistory,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final data = <String, dynamic>{
      'first_name': _firstName.text.trim(),
      'last_name':  _lastName.text.trim(),
      'date_of_birth': _dob.text.trim(),
      'gender': _gender,
      if (_bloodType != null) 'blood_type': _bloodType,
      if (_phone.text.trim().isNotEmpty) 'phone': _phone.text.trim(),
      if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
      if (_address.text.trim().isNotEmpty) 'address': _address.text.trim(),
      if (_emergencyName.text.trim().isNotEmpty)
        'emergency_contact_name': _emergencyName.text.trim(),
      if (_emergencyPhone.text.trim().isNotEmpty)
        'emergency_contact_phone': _emergencyPhone.text.trim(),
      'allergies': _allergies.map((a) => {
        'name': a['name']!,
        'severity': a['severity']!,
      }).toList(),
      'current_medications': _medications.map((m) => {
        'name': m['name']!,
        if ((m['dosage'] ?? '').isNotEmpty) 'dosage': m['dosage'],
      }).toList(),
      'chronic_conditions': _conditions,
      if (_insuranceProvider.text.trim().isNotEmpty)
        'insurance_provider': _insuranceProvider.text.trim(),
      if (_insuranceNumber.text.trim().isNotEmpty)
        'insurance_number': _insuranceNumber.text.trim(),
      if (_medicalHistory.text.trim().isNotEmpty)
        'medical_history': _medicalHistory.text.trim(),
    };

    final provider = context.read<PatientProvider>();
    PatientModel? result;

    if (widget.isEditing) {
      result = await provider.updatePatient(widget.patient!.id, data);
    } else {
      result = await provider.createPatient(data);
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (result != null) {
      Navigator.of(context).pop(result);
    } else {
      showAdaptiveToast(context, provider.error ?? 'Failed to save patient', type: ToastType.error);
    }
  }

  // ── Date picker ──────────────────────────────────────────────────────────

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob.text.isNotEmpty
          ? DateTime.tryParse(_dob.text) ?? DateTime(now.year - 30)
          : DateTime(now.year - 30),
      firstDate: DateTime(now.year - 130),
      lastDate: DateTime(now.year - 1, now.month, now.day),
      helpText: 'Date of Birth',
    );
    if (picked != null) {
      _dob.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: kIsIOS
          ? CupertinoNavigationBar(
              middle: Text(
                  widget.isEditing ? 'Edit Patient' : 'New Patient'),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const CupertinoActivityIndicator()
                    : const Text('Save'),
              ),
            )
          : AppBar(
              title: Text(
                  widget.isEditing ? 'Edit Patient' : 'New Patient'),
              actions: [
                TextButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.white)))
                      : const Text('Save',
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
              _section('Basic Information'),
              _twoCol(
                _field(_firstName, 'First Name',
                    validator: _required('First name')),
                _field(_lastName, 'Last Name',
                    validator: _required('Last name')),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dob,
                readOnly: true,
                onTap: _pickDob,
                validator: _required('Date of birth'),
                decoration: const InputDecoration(
                  labelText: 'Date of Birth *',
                  hintText: 'YYYY-MM-DD',
                  prefixIcon: Icon(Icons.calendar_today),
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),
              ),
              const SizedBox(height: 12),
              _dropdownRow<String>(
                label: 'Gender *',
                value: _gender,
                items: _genders
                    .map((g) => DropdownMenuItem(
                        value: g.$1, child: Text(g.$2)))
                    .toList(),
                onChanged: (v) => setState(() => _gender = v!),
              ),
              const SizedBox(height: 12),
              _dropdownRow<String?>(
                label: 'Blood Type',
                value: _bloodType,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Unknown')),
                  ..._bloodTypes.map((t) =>
                      DropdownMenuItem(value: t, child: Text(t))),
                ],
                onChanged: (v) => setState(() => _bloodType = v),
              ),

              _section('Contact Information'),
              _field(_phone, 'Phone', keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _field(_email, 'Email',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v != null && v.isNotEmpty && !v.contains('@')) {
                      return 'Enter a valid email';
                    }
                    return null;
                  }),
              const SizedBox(height: 12),
              _field(_address, 'Address', maxLines: 2),

              _section('Emergency Contact'),
              _field(_emergencyName, 'Contact Name'),
              const SizedBox(height: 12),
              _field(_emergencyPhone, 'Contact Phone',
                  keyboardType: TextInputType.phone),

              _section('Allergies'),
              ..._allergies.asMap().entries.map((e) =>
                  _allergyRow(e.key, e.value)),
              _addButton('Add Allergy', Icons.add, () {
                setState(() => _allergies.add(
                    {'name': '', 'severity': 'mild'}));
              }),

              _section('Current Medications'),
              ..._medications.asMap().entries.map((e) =>
                  _medicationRow(e.key, e.value)),
              _addButton('Add Medication', Icons.medication, () {
                setState(() => _medications.add({'name': '', 'dosage': ''}));
              }),

              _section('Chronic Conditions'),
              ..._conditions.asMap().entries.map((e) =>
                  _conditionRow(e.key, e.value)),
              _addButton('Add Condition', Icons.add_circle_outline, () {
                setState(() => _conditions.add(''));
              }),

              _section('Insurance'),
              _field(_insuranceProvider, 'Insurance Provider'),
              const SizedBox(height: 12),
              _field(_insuranceNumber, 'Policy / Insurance Number'),

              _section('Medical History'),
              _field(_medicalHistory, 'Medical history, past surgeries, notes…',
                  maxLines: 5),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section helpers ───────────────────────────────────────────────────────

  Widget _section(String title) => Padding(
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

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _twoCol(Widget left, Widget right) => Row(
        children: [
          Expanded(child: left),
          const SizedBox(width: 12),
          Expanded(child: right),
        ],
      );

  Widget _dropdownRow<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return AdaptiveDropdown<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label),
    );
  }

  // ── Array row builders ────────────────────────────────────────────────────

  Widget _allergyRow(int index, Map<String, String> allergy) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                initialValue: allergy['name'],
                decoration: const InputDecoration(
                    labelText: 'Allergen', isDense: true),
                validator: _required('Allergen name'),
                onChanged: (v) => allergy['name'] = v,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: AdaptiveDropdown<String>(
                value: allergy['severity'],
                decoration: const InputDecoration(
                    labelText: 'Severity', isDense: true),
                items: _severities
                    .map((s) => DropdownMenuItem(
                        value: s.$1, child: Text(s.$2)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => allergy['severity'] = v!),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              color: AppTheme.errorColor,
              onPressed: () =>
                  setState(() => _allergies.removeAt(index)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _medicationRow(int index, Map<String, String> med) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                initialValue: med['name'],
                decoration: const InputDecoration(
                    labelText: 'Medication', isDense: true),
                validator: _required('Medication name'),
                onChanged: (v) => med['name'] = v,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextFormField(
                initialValue: med['dosage'],
                decoration: const InputDecoration(
                    labelText: 'Dosage (optional)', isDense: true),
                onChanged: (v) => med['dosage'] = v,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              color: AppTheme.errorColor,
              onPressed: () =>
                  setState(() => _medications.removeAt(index)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _conditionRow(int index, String condition) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: condition,
                decoration: const InputDecoration(
                    labelText: 'Condition', isDense: true),
                validator: _required('Condition'),
                onChanged: (v) =>
                    setState(() => _conditions[index] = v),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              color: AppTheme.errorColor,
              onPressed: () =>
                  setState(() => _conditions.removeAt(index)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addButton(String label, IconData icon, VoidCallback onTap) {
    return AdaptiveTextButton(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      child: Text(label),
    );
  }

  String? Function(String?) _required(String field) =>
      (v) => (v == null || v.trim().isEmpty) ? '$field is required' : null;
}
