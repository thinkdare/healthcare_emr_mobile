// lib/data/models/ward_models.dart

class WardModel {
  final String id;
  final String name;
  final int bedCount;
  final int availableBedCount;

  const WardModel({
    required this.id,
    required this.name,
    required this.bedCount,
    required this.availableBedCount,
  });

  factory WardModel.fromJson(Map<String, dynamic> json) => WardModel(
        id: json['id'] as String,
        name: json['name'] as String,
        bedCount: (json['bed_count'] as num?)?.toInt() ?? 0,
        availableBedCount: (json['available_bed_count'] as num?)?.toInt() ?? 0,
      );
}

class WardAccessGrantModel {
  final String id;
  final String wardId;
  final String? wardName;
  final String grantedAt;
  final String? grantedBy;

  const WardAccessGrantModel({
    required this.id,
    required this.wardId,
    this.wardName,
    required this.grantedAt,
    this.grantedBy,
  });

  factory WardAccessGrantModel.fromJson(Map<String, dynamic> json) =>
      WardAccessGrantModel(
        id: json['id'] as String,
        wardId: json['ward_id'] as String,
        wardName: json['ward_name'] as String?,
        grantedAt: json['granted_at'] as String,
        grantedBy: json['granted_by'] as String?,
      );
}

class AdmissionRequestModel {
  final String id;
  final String patientId;
  final String wardId;
  final String? bedId;
  final String admissionType; // elective | emergency
  final String reason;
  final String status; // pending | accepted | rejected | cancelled
  final String? rejectionReason;
  final String? admissionId;
  final String requestedAt;
  final String? reviewedAt;

  const AdmissionRequestModel({
    required this.id,
    required this.patientId,
    required this.wardId,
    this.bedId,
    required this.admissionType,
    required this.reason,
    required this.status,
    this.rejectionReason,
    this.admissionId,
    required this.requestedAt,
    this.reviewedAt,
  });

  bool get isPending => status == 'pending';

  factory AdmissionRequestModel.fromJson(Map<String, dynamic> json) =>
      AdmissionRequestModel(
        id: json['id'] as String,
        patientId: json['patient_id'] as String,
        wardId: json['ward_id'] as String,
        bedId: json['bed_id'] as String?,
        admissionType: json['admission_type'] as String,
        reason: json['reason'] as String,
        status: json['status'] as String,
        rejectionReason: json['rejection_reason'] as String?,
        admissionId: json['admission_id'] as String?,
        requestedAt: json['requested_at'] as String,
        reviewedAt: json['reviewed_at'] as String?,
      );
}

class WardTransferRequestModel {
  final String id;
  final String patientId;
  final String admissionId;
  final String fromWardId;
  final String toWardId;
  final String? fromBedId;
  final String? toBedId;
  final String reason;
  final String status;
  final String? rejectionReason;
  final String? newAdmissionId;
  final String requestedAt;
  final String? reviewedAt;

  const WardTransferRequestModel({
    required this.id,
    required this.patientId,
    required this.admissionId,
    required this.fromWardId,
    required this.toWardId,
    this.fromBedId,
    this.toBedId,
    required this.reason,
    required this.status,
    this.rejectionReason,
    this.newAdmissionId,
    required this.requestedAt,
    this.reviewedAt,
  });

  bool get isPending => status == 'pending';

  factory WardTransferRequestModel.fromJson(Map<String, dynamic> json) =>
      WardTransferRequestModel(
        id: json['id'] as String,
        patientId: json['patient_id'] as String,
        admissionId: json['admission_id'] as String,
        fromWardId: json['from_ward_id'] as String,
        toWardId: json['to_ward_id'] as String,
        fromBedId: json['from_bed_id'] as String?,
        toBedId: json['to_bed_id'] as String?,
        reason: json['reason'] as String,
        status: json['status'] as String,
        rejectionReason: json['rejection_reason'] as String?,
        newAdmissionId: json['new_admission_id'] as String?,
        requestedAt: json['requested_at'] as String,
        reviewedAt: json['reviewed_at'] as String?,
      );
}

class DischargeSignoffModel {
  final String id;
  final String departmentType;
  final String status; // pending | approved | rejected | overridden
  final String? signedAt;
  final String? notes;
  final String? overriddenAt;

  const DischargeSignoffModel({
    required this.id,
    required this.departmentType,
    required this.status,
    this.signedAt,
    this.notes,
    this.overriddenAt,
  });

  factory DischargeSignoffModel.fromJson(Map<String, dynamic> json) =>
      DischargeSignoffModel(
        id: json['id'] as String,
        departmentType: json['department_type'] as String,
        status: json['status'] as String,
        signedAt: json['signed_at'] as String?,
        notes: json['notes'] as String?,
        overriddenAt: json['overridden_at'] as String?,
      );
}

class DischargeRequestModel {
  final String id;
  final String patientId;
  final String admissionId;
  final String status; // pending | records_approved | discharged | cancelled
  final String dischargeType; // routine | against_medical_advice | deceased | transfer
  final String? dischargeSummary;
  final String? approvedAt;
  final String? dischargedAt;
  final String initiatedAt;
  final List<DischargeSignoffModel> signoffs;

  const DischargeRequestModel({
    required this.id,
    required this.patientId,
    required this.admissionId,
    required this.status,
    required this.dischargeType,
    this.dischargeSummary,
    this.approvedAt,
    this.dischargedAt,
    required this.initiatedAt,
    this.signoffs = const [],
  });

  bool get allSignoffsApproved =>
      signoffs.isNotEmpty &&
      signoffs.every((s) => s.status == 'approved' || s.status == 'overridden');
  bool get canRecordsApprove => allSignoffsApproved && status == 'pending';
  bool get canExecute => status == 'records_approved';

  factory DischargeRequestModel.fromJson(Map<String, dynamic> json) {
    final rawSignoffs = json['signoffs'];
    return DischargeRequestModel(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      admissionId: json['admission_id'] as String,
      status: json['status'] as String,
      dischargeType: json['discharge_type'] as String,
      dischargeSummary: json['discharge_summary'] as String?,
      approvedAt: json['approved_at'] as String?,
      dischargedAt: json['discharged_at'] as String?,
      initiatedAt: json['initiated_at'] as String,
      signoffs: rawSignoffs is List
          ? rawSignoffs
              .map((e) => DischargeSignoffModel.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList()
          : const [],
    );
  }
}
