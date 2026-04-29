// Clinical models — hand-written fromJson (no build_runner needed).
//
// All clinical resources are patient-scoped:
//   GET /api/v1/patients/{patientId}/appointments
//   GET /api/v1/patients/{patientId}/prescriptions
//   GET /api/v1/patients/{patientId}/lab-results
//   GET /api/v1/patients/{patientId}/documents

// ── Appointment ───────────────────────────────────────────────────────────────

class AppointmentModel {
  final String id;
  final String patientId;
  final String providerId;
  final DateTime appointmentDate;
  final int durationMinutes;
  final String appointmentType;
  // 'scheduled'|'confirmed'|'checked_in'|'completed'|'cancelled'|'no_show'
  final String status;
  final String? reason;
  final String? notes;
  final String? cancellationReason;
  final bool reminderSent;
  final DateTime? checkedInAt;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? wardId;

  const AppointmentModel({
    required this.id,
    required this.patientId,
    required this.providerId,
    required this.appointmentDate,
    required this.durationMinutes,
    required this.appointmentType,
    required this.status,
    this.reason,
    this.notes,
    this.cancellationReason,
    required this.reminderSent,
    this.checkedInAt,
    this.completedAt,
    this.createdAt,
    this.updatedAt,
    this.wardId,
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    return AppointmentModel(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      providerId: json['provider_id'] as String,
      appointmentDate: DateTime.parse(json['appointment_date'] as String),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 30,
      appointmentType: json['appointment_type'] as String? ?? 'consultation',
      status: json['status'] as String? ?? 'scheduled',
      reason: json['reason'] as String?,
      notes: json['notes'] as String?,
      cancellationReason: json['cancellation_reason'] as String?,
      reminderSent: json['reminder_sent'] as bool? ?? false,
      checkedInAt: json['checked_in_at'] != null
          ? DateTime.tryParse(json['checked_in_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      wardId: json['ward_id'] as String?,
    );
  }

  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isUpcoming =>
      !isCompleted && !isCancelled && appointmentDate.isAfter(DateTime.now());
  bool get isToday {
    final now = DateTime.now();
    return appointmentDate.year == now.year &&
        appointmentDate.month == now.month &&
        appointmentDate.day == now.day;
  }
}

// ── Prescription ──────────────────────────────────────────────────────────────

class PrescriptionModel {
  final String id;
  final String patientId;
  final String prescriberId;
  final String medicationName;
  final String? medicationCode;
  final String dosage;
  final String frequency;
  final String? route;
  final int? durationDays;
  final int? quantity;
  final int refillsAllowed;
  final int refillsRemaining;
  final DateTime? prescribedDate;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? expiresDate;
  // 'pending'|'active'|'filled'|'expired'|'cancelled'|'discontinued'
  final String status;
  final String? specialInstructions;
  final String? discontinuationReason;
  final bool drugInteractionsChecked;
  final String? wardId;
  final String? codingSystem;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PrescriptionModel({
    required this.id,
    required this.patientId,
    required this.prescriberId,
    required this.medicationName,
    this.medicationCode,
    required this.dosage,
    required this.frequency,
    this.route,
    this.durationDays,
    this.quantity,
    required this.refillsAllowed,
    required this.refillsRemaining,
    this.prescribedDate,
    this.startDate,
    this.endDate,
    this.expiresDate,
    required this.status,
    this.specialInstructions,
    this.discontinuationReason,
    required this.drugInteractionsChecked,
    this.wardId,
    this.codingSystem,
    this.createdAt,
    this.updatedAt,
  });

  factory PrescriptionModel.fromJson(Map<String, dynamic> json) {
    DateTime? _date(String key) {
      final v = json[key];
      if (v == null) return null;
      return DateTime.tryParse(v as String);
    }

    return PrescriptionModel(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      prescriberId: json['prescriber_id'] as String,
      medicationName: json['medication_name'] as String,
      medicationCode: json['medication_code'] as String?,
      dosage: json['dosage'] as String? ?? '',
      frequency: json['frequency'] as String? ?? '',
      route: json['route'] as String?,
      durationDays: (json['duration_days'] as num?)?.toInt(),
      quantity: (json['quantity'] as num?)?.toInt(),
      refillsAllowed: (json['refills_allowed'] as num?)?.toInt() ?? 0,
      refillsRemaining: (json['refills_remaining'] as num?)?.toInt() ?? 0,
      prescribedDate: _date('prescribed_date'),
      startDate: _date('start_date'),
      endDate: _date('end_date'),
      expiresDate: _date('expires_date'),
      status: json['status'] as String? ?? 'active',
      specialInstructions: json['special_instructions'] as String?,
      discontinuationReason: json['discontinuation_reason'] as String?,
      drugInteractionsChecked: json['drug_interactions_checked'] as bool? ?? false,
      wardId: json['ward_id'] as String?,
      codingSystem: json['coding_system'] as String?,
      createdAt: _date('created_at'),
      updatedAt: _date('updated_at'),
    );
  }

  bool get isActive =>
      status != 'expired' && status != 'cancelled' && status != 'discontinued';
  bool get canRefill => isActive && refillsRemaining > 0;

  String get doseDisplay {
    final parts = [dosage, frequency, if (route != null) route!];
    return parts.join(' · ');
  }
}

// ── LabResult ─────────────────────────────────────────────────────────────────

class LabResultModel {
  final String id;
  final String patientId;
  final String orderedById;
  final String? performedById;
  final String? reviewedById;
  final String testName;
  final String? testCode;
  final String? testType;
  // 'routine'|'urgent'|'stat'
  final String priority;
  final String? results;
  final String? interpretation;
  final List<String> abnormalFlags;
  // 'pending'|'sample_collected'|'processing'|'completed'|'cancelled'
  final String status;
  final DateTime? orderedDate;
  final DateTime? sampleCollectedAt;
  final DateTime? completedAt;
  final DateTime? reviewedAt;
  final String? filePath;
  final bool requiresFollowup;
  final String? wardId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const LabResultModel({
    required this.id,
    required this.patientId,
    required this.orderedById,
    this.performedById,
    this.reviewedById,
    required this.testName,
    this.testCode,
    this.testType,
    required this.priority,
    this.results,
    this.interpretation,
    required this.abnormalFlags,
    required this.status,
    this.orderedDate,
    this.sampleCollectedAt,
    this.completedAt,
    this.reviewedAt,
    this.filePath,
    required this.requiresFollowup,
    this.wardId,
    this.createdAt,
    this.updatedAt,
  });

  factory LabResultModel.fromJson(Map<String, dynamic> json) {
    DateTime? _dt(String key) {
      final v = json[key];
      if (v == null) return null;
      return DateTime.tryParse(v as String);
    }

    return LabResultModel(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      orderedById: json['ordered_by_id'] as String,
      performedById: json['performed_by_id'] as String?,
      reviewedById: json['reviewed_by_id'] as String?,
      testName: json['test_name'] as String,
      testCode: json['test_code'] as String?,
      testType: json['test_type'] as String?,
      priority: json['priority'] as String? ?? 'routine',
      results: json['results'] as String?,
      interpretation: json['interpretation'] as String?,
      abnormalFlags: (json['abnormal_flags'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      status: json['status'] as String? ?? 'pending',
      orderedDate: _dt('ordered_date'),
      sampleCollectedAt: _dt('sample_collected_at'),
      completedAt: _dt('completed_at'),
      reviewedAt: _dt('reviewed_at'),
      filePath: json['file_path'] as String?,
      requiresFollowup: json['requires_followup'] as bool? ?? false,
      wardId: json['ward_id'] as String?,
      createdAt: _dt('created_at'),
      updatedAt: _dt('updated_at'),
    );
  }

  bool get isCompleted => status == 'completed';
  bool get isPending => status == 'pending' || status == 'sample_collected' || status == 'processing';
  bool get isUrgent => priority == 'urgent' || priority == 'stat';
  bool get hasAbnormalResults => abnormalFlags.isNotEmpty;
}

// ── MedicalDocument ───────────────────────────────────────────────────────────

class MedicalDocumentModel {
  final String id;
  final String patientId;
  final String uploadedById;
  final String title;
  final String documentType;
  final String? originalFilename;
  final String? mimeType;
  final int? fileSize;
  final String? notes;
  final bool isConfidential;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  // Signed URL (from GET /documents/{id})
  final String? temporaryUrl;

  const MedicalDocumentModel({
    required this.id,
    required this.patientId,
    required this.uploadedById,
    required this.title,
    required this.documentType,
    this.originalFilename,
    this.mimeType,
    this.fileSize,
    this.notes,
    required this.isConfidential,
    this.createdAt,
    this.updatedAt,
    this.temporaryUrl,
  });

  factory MedicalDocumentModel.fromJson(Map<String, dynamic> json) {
    DateTime? _dt(String key) {
      final v = json[key];
      if (v == null) return null;
      return DateTime.tryParse(v as String);
    }

    return MedicalDocumentModel(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      uploadedById: json['uploaded_by_id'] as String,
      title: json['title'] as String? ?? 'Untitled Document',
      documentType: json['document_type'] as String? ?? 'other',
      originalFilename: json['original_filename'] as String?,
      mimeType: json['mime_type'] as String?,
      fileSize: (json['file_size'] as num?)?.toInt(),
      notes: json['notes'] as String?,
      isConfidential: json['is_confidential'] as bool? ?? false,
      createdAt: _dt('created_at'),
      updatedAt: _dt('updated_at'),
      temporaryUrl: json['temporary_url'] as String?,
    );
  }

  bool get isPdf => mimeType == 'application/pdf';
  bool get isImage => mimeType?.startsWith('image/') == true;

  String get fileSizeDisplay {
    if (fileSize == null) return '';
    if (fileSize! < 1024) return '${fileSize}B';
    if (fileSize! < 1024 * 1024) return '${(fileSize! / 1024).toStringAsFixed(1)}KB';
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}
