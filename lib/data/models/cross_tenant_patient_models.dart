// lib/data/models/cross_tenant_patient_models.dart

class CrossTenantPatientModel {
  final String id;
  final String fullName;
  final String firstName;
  final String lastName;
  final String? dateOfBirth;
  final String? gender;
  final String? bloodType;
  final String? currentMedications;
  final String? allergies;
  final String? chronicConditions;
  final String? medicalHistory;

  const CrossTenantPatientModel({
    required this.id,
    required this.fullName,
    required this.firstName,
    required this.lastName,
    this.dateOfBirth,
    this.gender,
    this.bloodType,
    this.currentMedications,
    this.allergies,
    this.chronicConditions,
    this.medicalHistory,
  });

  factory CrossTenantPatientModel.fromJson(Map<String, dynamic> json) =>
      CrossTenantPatientModel(
        id: json['id'] as String,
        fullName: json['full_name'] as String,
        firstName: json['first_name'] as String,
        lastName: json['last_name'] as String,
        dateOfBirth: json['date_of_birth'] as String?,
        gender: json['gender'] as String?,
        bloodType: json['blood_type'] as String?,
        currentMedications: json['current_medications'] as String?,
        allergies: json['allergies'] as String?,
        chronicConditions: json['chronic_conditions'] as String?,
        medicalHistory: json['medical_history'] as String?,
      );
}

class CrossTenantPrescriptionModel {
  final String id;
  final String medicationName;
  final String? dosage;
  final String? frequency;
  final String status;
  final String? prescribedDate;

  const CrossTenantPrescriptionModel({
    required this.id,
    required this.medicationName,
    this.dosage,
    this.frequency,
    required this.status,
    this.prescribedDate,
  });

  factory CrossTenantPrescriptionModel.fromJson(Map<String, dynamic> json) =>
      CrossTenantPrescriptionModel(
        id: json['id'] as String,
        medicationName: json['medication_name'] as String,
        dosage: json['dosage'] as String?,
        frequency: json['frequency'] as String?,
        status: json['status'] as String,
        prescribedDate: json['prescribed_date'] as String?,
      );
}

class CrossTenantLabResultModel {
  final String id;
  final String testName;
  final String? testType;
  final String? orderedDate;
  final String status;
  final dynamic results;

  const CrossTenantLabResultModel({
    required this.id,
    required this.testName,
    this.testType,
    this.orderedDate,
    required this.status,
    this.results,
  });

  factory CrossTenantLabResultModel.fromJson(Map<String, dynamic> json) =>
      CrossTenantLabResultModel(
        id: json['id'] as String,
        testName: json['test_name'] as String,
        testType: json['test_type'] as String?,
        orderedDate: json['ordered_date'] as String?,
        status: json['status'] as String,
        results: json['results'],
      );
}

class CrossTenantAppointmentModel {
  final String id;
  final String? appointmentDate;
  final String? appointmentType;
  final String status;

  const CrossTenantAppointmentModel({
    required this.id,
    this.appointmentDate,
    this.appointmentType,
    required this.status,
  });

  factory CrossTenantAppointmentModel.fromJson(Map<String, dynamic> json) =>
      CrossTenantAppointmentModel(
        id: json['id'] as String,
        appointmentDate: json['appointment_date'] as String?,
        appointmentType: json['appointment_type'] as String?,
        status: json['status'] as String,
      );
}
